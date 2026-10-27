param(
    [string]$Version = "0.0.0"
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$pyVersion = "3.11.9"
$bundle = Join-Path $root "bundle"
$python = Join-Path $bundle "python"
$pythonExe = Join-Path $python "python.exe"
$dist = Join-Path $root "dist"

function Get-PythonEmbed {
    if (Test-Path $pythonExe) {
        & $pythonExe -c "import pymobiledevice3" 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Output "python runtime ready"
            return
        }
    }

    New-Item -ItemType Directory -Force -Path $python | Out-Null
    $zip = Join-Path $env:TEMP "python-$pyVersion-embed-amd64.zip"
    if (-not (Test-Path $zip)) {
        Write-Output "downloading Python $pyVersion embeddable"
        Invoke-WebRequest -Uri "https://www.python.org/ftp/python/$pyVersion/python-$pyVersion-embed-amd64.zip" -OutFile $zip
    }
    Expand-Archive -Path $zip -DestinationPath $python -Force
    $pth = Get-ChildItem $python -Filter "python*._pth" | Select-Object -First 1
    if ($null -eq $pth) { throw "python ._pth not found" }
    @(
        "python311.zip"
        "."
        "Lib\site-packages"
        "import site"
    ) | Set-Content -Encoding ascii $pth.FullName

    $getPip = Join-Path $env:TEMP "get-pip.py"
    if (-not (Test-Path $getPip)) {
        Invoke-WebRequest -Uri "https://bootstrap.pypa.io/get-pip.py" -OutFile $getPip
    }
    & $pythonExe $getPip --no-warn-script-location
    if ($LASTEXITCODE -ne 0) { throw "get-pip failed" }
    Write-Output "installing pymobiledevice3"
    & $pythonExe -m pip install --disable-pip-version-check --progress-bar off --timeout 60 --retries 5 --no-warn-script-location "pymobiledevice3==11.45.0"
    if ($LASTEXITCODE -ne 0) {
        Write-Output "PyPI timed out, retrying via the Tsinghua mirror"
        & $pythonExe -m pip install --disable-pip-version-check --progress-bar off --timeout 60 --retries 5 --no-warn-script-location --index-url "https://pypi.tuna.tsinghua.edu.cn/simple" --trusted-host "pypi.tuna.tsinghua.edu.cn" "pymobiledevice3==11.45.0"
    }
    if ($LASTEXITCODE -ne 0) { throw "pymobiledevice3 install failed" }
    & $pythonExe -c "import pymobiledevice3"
    if ($LASTEXITCODE -ne 0) { throw "bundled python cannot import pymobiledevice3" }
}

Write-Output "building signer"
cargo build --release --manifest-path (Join-Path $root "signer\Cargo.toml")
if ($LASTEXITCODE -ne 0) { throw "cargo build failed" }

Get-PythonEmbed
New-Item -ItemType Directory -Force -Path $bundle | Out-Null
Copy-Item (Join-Path $root "signer\target\release\selfrefresh-sign.exe") (Join-Path $bundle "selfrefresh-sign.exe") -Force

if (Test-Path $dist) { Remove-Item $dist -Recurse -Force }
Write-Output "publishing single file"
dotnet publish (Join-Path $root "SelfRefreshSetup.csproj") -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true -p:IncludeAllContentForSelfExtract=true -p:EnableCompressionInSingleFile=true -p:DebugType=none -p:DebugSymbols=false -p:AssemblyName=SelfRefreshKit -p:Version=$Version -o $dist
if ($LASTEXITCODE -ne 0) { throw "dotnet publish failed" }

$files = @(Get-ChildItem $dist -File)
$extra = @($files | Where-Object { $_.Name -ne "SelfRefreshKit.exe" })
if ($extra.Count -gt 0) {
    $extra | ForEach-Object { Write-Output ("extra " + $_.Name) }
    throw "publish output is not a single file"
}
$exe = Join-Path $dist "SelfRefreshKit.exe"
Write-Output ("portable " + $exe + " " + (Get-Item $exe).Length)
