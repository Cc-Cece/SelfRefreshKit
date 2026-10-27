param(
    [string]$Version = "0.0.0"
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
if (Get-Variable -Name PSNativeCommandUseErrorActionPreference -ErrorAction SilentlyContinue) {
    $PSNativeCommandUseErrorActionPreference = $false
}

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$pyVersion = "3.11.9"
$bundle = Join-Path $root "bundle"
$python = Join-Path $bundle "python"
$pythonExe = Join-Path $python "python.exe"
$site = Join-Path $python "Lib\site-packages"
$dist = Join-Path $root "dist"
$checkPath = Join-Path $env:TEMP "selfrefresh-bundle-check.py"

@'
import importlib
import importlib.util

banned = ("av", "PIL", "IPython", "fastapi", "pmd_pytcp", "uvicorn", "pyimg4")
present = [name for name in banned if importlib.util.find_spec(name) is not None]
if present:
    raise SystemExit("unused packages still present: " + ",".join(present))
mods = (
    "pymobiledevice3.exceptions",
    "pymobiledevice3.remote.tunnel_service",
    "pymobiledevice3.pair_records",
    "cryptography.hazmat.primitives.asymmetric.ed25519",
    "pymobiledevice3.lockdown",
    "pymobiledevice3.services.house_arrest",
    "pymobiledevice3.services.installation_proxy",
    "pymobiledevice3.usbmux",
    "win32security",
)
for name in mods:
    importlib.import_module(name)
print("worker imports ok")
'@ | Set-Content -Encoding ascii $checkPath

function Test-WorkerImports {
    & $pythonExe $checkPath | Out-Null
    return $LASTEXITCODE -eq 0
}

function Invoke-Pip {
    param([string[]]$PipArgs)
    $flags = @(
        "--disable-pip-version-check",
        "--progress-bar", "off",
        "--timeout", "120",
        "--retries", "5",
        "--no-warn-script-location"
    )
    & $pythonExe -m pip @PipArgs @flags
    if ($LASTEXITCODE -eq 0) { return }
    Write-Output "PyPI timed out, retrying via the Tsinghua mirror"
    & $pythonExe -m pip @PipArgs @flags --index-url "https://pypi.tuna.tsinghua.edu.cn/simple" --trusted-host "pypi.tuna.tsinghua.edu.cn"
    if ($LASTEXITCODE -ne 0) { throw "pip failed: $($PipArgs -join ' ')" }
}

function Install-Pip {
    $getPip = Join-Path $env:TEMP "get-pip.py"
    if (-not (Test-Path $getPip)) {
        Invoke-WebRequest -Uri "https://bootstrap.pypa.io/get-pip.py" -OutFile $getPip
    }
    & $pythonExe $getPip --no-warn-script-location
    if ($LASTEXITCODE -ne 0) { throw "get-pip failed" }
}

function Install-SlimPython {
    if (Test-Path $site) { Remove-Item $site -Recurse -Force }
    New-Item -ItemType Directory -Force -Path $site | Out-Null
    Install-Pip
    Write-Output "installing slim pymobiledevice3"
    Invoke-Pip @(
        "install", "--only-binary=:all:", "--no-deps", "pymobiledevice3==11.45.0"
    )
    Invoke-Pip @(
        "install", "--only-binary=:all:",
        "bytestruct>=0.1.0",
        "cryptography>=43.0.0",
        "ifaddr",
        "opack2>=0.1.0",
        "packaging",
        "prompt_toolkit",
        "psutil",
        "pygnuutils>=0.0.7",
        "pytun-pmd3>=3.0.3",
        "pywin32",
        "qh3>=1.0.0,<2",
        "questionary>=2.0.0",
        "requests",
        "rich>=13.0.0",
        "srptools",
        "typing_extensions>=4.1.0",
        "hyperframe"
    )
}

function Remove-PyWin32Extras {
    foreach ($name in @("pythonwin", "win32com", "win32comext", "adodbapi")) {
        $path = Join-Path $site $name
        if (Test-Path $path) { Remove-Item $path -Recurse -Force }
    }
}

function Remove-PipTooling {
    foreach ($name in @("pip", "setuptools", "wheel", "pkg_resources", "_distutils_hack")) {
        $path = Join-Path $site $name
        if (Test-Path $path) { Remove-Item $path -Recurse -Force }
    }
    if (Test-Path $site) {
        Get-ChildItem $site -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match "^(pip|setuptools|wheel)-.+\.dist-info$" } |
            ForEach-Object { Remove-Item $_.FullName -Recurse -Force }
        $setuptoolsPth = Join-Path $site "distutils-precedence.pth"
        if (Test-Path $setuptoolsPth) { Remove-Item $setuptoolsPth -Force }
    }
    Get-ChildItem $python -Recurse -Directory -Filter "__pycache__" -ErrorAction SilentlyContinue |
        ForEach-Object { Remove-Item $_.FullName -Recurse -Force }
}

function Write-PythonPath {
    $pth = Get-ChildItem $python -Filter "python*._pth" | Select-Object -First 1
    if ($null -eq $pth) { throw "python ._pth not found" }
    @(
        "python311.zip"
        "."
        ".."
        "Lib\site-packages"
        "import site"
        # ".." is the published folder beside python\, which holds worker.py and i18n.py.
    ) | Set-Content -Encoding ascii $pth.FullName
}

function Get-PythonEmbed {
    if (Test-Path $pythonExe) { Write-PythonPath }
    if ((Test-Path $pythonExe) -and (Test-WorkerImports)) {
        Remove-PyWin32Extras
        Remove-PipTooling
        if (-not (Test-WorkerImports)) { throw "slimming an existing python runtime broke imports" }
        Write-Output "python runtime ready"
        return
    }

    New-Item -ItemType Directory -Force -Path $python | Out-Null
    $zip = Join-Path $env:TEMP "python-$pyVersion-embed-amd64.zip"
    if (-not (Test-Path $pythonExe)) {
        if (-not (Test-Path $zip)) {
            Write-Output "downloading Python $pyVersion embeddable"
            Invoke-WebRequest -Uri "https://www.python.org/ftp/python/$pyVersion/python-$pyVersion-embed-amd64.zip" -OutFile $zip
        }
        Expand-Archive -Path $zip -DestinationPath $python -Force
    }
    Write-PythonPath
    Install-SlimPython
    if (-not (Test-WorkerImports)) { throw "bundled python cannot import the worker modules" }
    Remove-PyWin32Extras
    if (-not (Test-WorkerImports)) { throw "removing unused pywin32 parts broke imports" }
    Remove-PipTooling
    if (-not (Test-WorkerImports)) { throw "removing pip broke imports" }
    Write-Output "python runtime slim"
}

Write-Output "building signer"
cargo build --release --manifest-path (Join-Path $root "signer\Cargo.toml")
if ($LASTEXITCODE -ne 0) { throw "cargo build failed" }

Get-PythonEmbed
New-Item -ItemType Directory -Force -Path $bundle | Out-Null
Copy-Item (Join-Path $root "signer\target\release\selfrefresh-sign.exe") (Join-Path $bundle "selfrefresh-sign.exe") -Force

if (Test-Path $dist) { Remove-Item $dist -Recurse -Force }
Write-Output "publishing framework-dependent single file"
dotnet publish (Join-Path $root "SelfRefreshSetup.csproj") -c Release -r win-x64 --self-contained false -p:SelfContained=false -p:PublishSelfContained=false -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true -p:IncludeAllContentForSelfExtract=true -p:EnableCompressionInSingleFile=false -p:DebugType=none -p:DebugSymbols=false -p:AssemblyName=SelfRefreshKit -p:Version=$Version -o $dist
if ($LASTEXITCODE -ne 0) { throw "dotnet publish failed" }

$files = @(Get-ChildItem $dist -File)
$extra = @($files | Where-Object { $_.Name -ne "SelfRefreshKit.exe" })
if ($extra.Count -gt 0) {
    $extra | ForEach-Object { Write-Output ("extra " + $_.Name) }
    throw "publish output is not a single file"
}
$exe = Join-Path $dist "SelfRefreshKit.exe"
$payload = [System.IO.File]::ReadAllBytes($exe)
$text = [System.Text.Encoding]::ASCII.GetString($payload)
if ($text.Contains("includedFrameworks")) { throw "publish is still self-contained" }
if (-not $text.Contains("Microsoft.WindowsDesktop.App")) { throw "publish is missing the .NET desktop runtime reference" }
Write-Output ("portable " + $exe + " " + $payload.Length)
