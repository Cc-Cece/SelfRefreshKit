using System.Diagnostics;
using System.IO;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Threading;
using Microsoft.Win32;

namespace SelfRefreshSetup;

public partial class MainWindow : Window
{
    static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNameCaseInsensitive = true
    };

    static readonly JsonSerializerOptions StoreJsonOptions = new()
    {
        PropertyNameCaseInsensitive = true,
        WriteIndented = true
    };

    static readonly byte[] AccountEntropy = "SelfRefreshSetup.account.v1"u8.ToArray();

    const int MaxSavedAccounts = 30;

    readonly DispatcherTimer poll = new() { Interval = TimeSpan.FromSeconds(5) };
    readonly SemaphoreSlim gate = new(1, 1);
    readonly string accountStorePath = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "SelfRefreshSetup",
        "accounts.json");
    readonly string legacyAppleIdStorePath = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "SelfRefreshSetup",
        "apple-ids.json");
    readonly List<AccountRecord> accounts = [];
    bool loadingAccounts;
    bool loadingLanguage;
    string? ipaPath;
    WorkerPayload? ipaInfo;
    Process? running;
    TaskCompletionSource<string>? twoFactorWait;
    bool busy;

    public MainWindow()
    {
        InitializeComponent();
        loadingLanguage = true;
        LanguageList.ItemsSource = Text.Languages;
        LanguageList.SelectedValue = Text.Lang;
        loadingLanguage = false;
        Text.LanguageChanged += OnLanguageChanged;
        poll.Tick += async (_, _) => await RefreshDevicesAsync();
        Loaded += async (_, _) =>
        {
            AppendLog(Text.Get("ready"));
            LoadAccounts();
            await RefreshDevicesAsync();
            poll.Start();
        };
        Closed += (_, _) =>
        {
            Text.LanguageChanged -= OnLanguageChanged;
            StopRunning();
        };
    }

    void LanguageList_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (loadingLanguage || LanguageList.SelectedValue is not string code)
        {
            return;
        }

        if (!Text.SetLanguage(code))
        {
            AppendLog(Text.Get("languageSaveFailed"));
        }
    }

    void OnLanguageChanged()
    {
        if (!Dispatcher.CheckAccess())
        {
            Dispatcher.Invoke(OnLanguageChanged);
            return;
        }

        var selected = (SavedAppleIdList.SelectedItem as AccountRow)?.AppleId;
        ShowAccounts(selected, false);
        if (ipaInfo != null)
        {
            IpaDetail.Text = DescribeIpa(ipaInfo);
        }

        if (busy)
        {
            PrimaryButton.Content = Text.Get("primaryStop");
        }
        else
        {
            UpdateButtons();
        }

        _ = RefreshDevicesAsync();
    }

    void PickIpa_Click(object sender, RoutedEventArgs e)
    {
        var dialog = new OpenFileDialog
        {
            Filter = Text.Get("ipaFilter"),
            Title = Text.Get("pickIpaTitle")
        };
        if (dialog.ShowDialog(this) != true)
        {
            return;
        }

        ipaPath = dialog.FileName;
        IpaTitle.Text = Path.GetFileName(ipaPath);
        IpaDetail.Text = Text.Get("ipaReading");
        ipaInfo = null;
        _ = InspectAsync(ipaPath);
    }

    async void RefreshDevices_Click(object sender, RoutedEventArgs e) => await RefreshDevicesAsync();

    void DeviceList_SelectionChanged(object sender, SelectionChangedEventArgs e) => UpdateButtons();

    async void PrimaryButton_Click(object sender, RoutedEventArgs e)
    {
        if (busy)
        {
            StopRunning();
            AppendLog(Text.Get("stopped"));
            return;
        }

        if (ipaPath == null || DeviceList.SelectedItem is not DeviceRow device)
        {
            return;
        }

        var signing = ipaInfo?.Installable != true;
        if (signing && !CredentialsReady())
        {
            return;
        }

        if (signing)
        {
            SaveCurrentAccount(announce: false);
        }

        SetBusy(true);
        AppendLog(Text.Get("started"));
        var timeout = signing ? TimeSpan.FromMinutes(20) : TimeSpan.FromMinutes(8);
        var result = await RunWorkerAsync(timeout, "run", "--ipa", ipaPath, "--udid", device.Udid);
        ShowResult(result);
        SetBusy(false);
        await RefreshDevicesAsync();
    }

    async void PrepareButton_Click(object sender, RoutedEventArgs e)
    {
        if (busy || ipaPath == null)
        {
            return;
        }

        var dest = Path.Combine(
            Path.GetDirectoryName(ipaPath) ?? "",
            Path.GetFileNameWithoutExtension(ipaPath) + ".filesharing.ipa");
        SetBusy(true);
        var result = await RunWorkerAsync(TimeSpan.FromMinutes(5), "prepare", "--ipa", ipaPath, "--out", dest);
        ShowResult(result);
        SetBusy(false);
    }

    async void ExportPairing_Click(object sender, RoutedEventArgs e)
    {
        if (busy || DeviceList.SelectedItem is not DeviceRow device)
        {
            return;
        }

        var dialog = new SaveFileDialog
        {
            Filter = Text.Get("pairingFilter"),
            FileName = "pairing.mobiledevicepairing",
            DefaultExt = ".mobiledevicepairing",
            Title = Text.Get("exportDialogTitle"),
            OverwritePrompt = true
        };
        if (dialog.ShowDialog(this) != true)
        {
            return;
        }

        SetBusy(true);
        AppendLog(Text.Get("exporting"));
        var result = await RunWorkerAsync(TimeSpan.FromMinutes(8), "export", "--udid", device.Udid, "--out", dialog.FileName);
        ShowResult(result);
        SetBusy(false);
        await RefreshDevicesAsync();
    }

    async Task InspectAsync(string path)
    {
        var result = await RunWorkerAsync(TimeSpan.FromSeconds(30), "inspect", "--ipa", path);
        if (result == null || result.Ok != true)
        {
            IpaDetail.Text = result?.Message ?? Text.Get("ipaReadFailed");
            ipaInfo = null;
        }
        else
        {
            ipaInfo = result;
            IpaTitle.Text = string.IsNullOrWhiteSpace(result.DisplayName) ? Path.GetFileName(path) : result.DisplayName;
            IpaDetail.Text = DescribeIpa(result);
            AppendLog(DescribeIpa(result));
        }

        UpdateButtons();
    }

    async Task RefreshDevicesAsync()
    {
        if (busy)
        {
            return;
        }

        var previous = (DeviceList.SelectedItem as DeviceRow)?.Udid;
        var result = await RunWorkerAsync(TimeSpan.FromSeconds(25), "devices");
        if (result == null)
        {
            return;
        }

        if (result.Ok != true)
        {
            DeviceList.ItemsSource = null;
            DeviceDetail.Text = result.Message ?? Text.Get("noDevices");
            UpdateButtons();
            return;
        }

        var rows = (result.Devices ?? []).Select(DeviceRow.From).ToList();
        DeviceList.ItemsSource = rows;
        if (rows.Count == 0)
        {
            DeviceDetail.Text = Text.Get("noDevices");
        }
        else
        {
            var match = rows.FirstOrDefault(row => row.Udid == previous) ?? rows[0];
            DeviceList.SelectedItem = match;
            DeviceDetail.Text = match.Detail;
        }

        UpdateButtons();
    }

    void UpdateButtons()
    {
        if (busy)
        {
            return;
        }

        var hasDevice = DeviceList.SelectedItem is DeviceRow;
        PrimaryButton.IsEnabled = ipaInfo != null && hasDevice;
        PrimaryButton.Content = ipaInfo?.Installable == true ? Text.Get("primaryInstall") : Text.Get("primarySign");
        PrepareButton.IsEnabled = ipaInfo != null && ipaInfo.Installable != true && ipaInfo.HasProvision != true && ipaInfo.HasSignature != true;
        ExportPairingButton.IsEnabled = hasDevice;
    }

    void SetBusy(bool value)
    {
        busy = value;
        if (value)
        {
            poll.Stop();
            PrimaryButton.IsEnabled = true;
            PrimaryButton.Content = Text.Get("primaryStop");
            PrepareButton.IsEnabled = false;
            ExportPairingButton.IsEnabled = false;
        }
        else
        {
            poll.Start();
            UpdateButtons();
        }
    }

    void ShowResult(WorkerPayload? result)
    {
        if (result == null)
        {
            AppendLog(Text.Get("noResult"));
            return;
        }

        if (!string.IsNullOrWhiteSpace(result.Warning))
        {
            AppendLog(result.Warning!);
        }

        AppendLog(result.Message ?? (result.Ok == true ? Text.Get("done") : Text.Get("notDone")));
        if (!string.IsNullOrWhiteSpace(result.PairingSaved))
        {
            AppendLog(Text.Format("localCopy", ("path", result.PairingSaved)));
        }

        if (!string.IsNullOrWhiteSpace(result.Output))
        {
            AppendLog(Text.Format("outputFile", ("path", result.Output)));
        }
    }

    async Task<WorkerPayload?> RunWorkerAsync(TimeSpan timeout, params string[] args)
    {
        var root = BundleDirectory();
        var worker = Path.Combine(root, "worker.py");
        if (!File.Exists(worker))
        {
            AppendLog(Text.Get("workerMissing"));
            return null;
        }

        var python = Path.Combine(root, "python", "python.exe");
        var bundledPython = File.Exists(python);
        var psi = new ProcessStartInfo
        {
            FileName = bundledPython ? python : "py",
            WorkingDirectory = root,
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            StandardOutputEncoding = Encoding.UTF8,
            StandardErrorEncoding = Encoding.UTF8,
            CreateNoWindow = true
        };
        if (!bundledPython)
        {
            psi.ArgumentList.Add("-3.11");
        }
        psi.ArgumentList.Add(worker);
        foreach (var arg in args)
        {
            psi.ArgumentList.Add(arg);
        }

        psi.Environment["PYTHONIOENCODING"] = "utf-8";
        psi.Environment["PYTHONUTF8"] = "1";
        psi.Environment["PYTHONDONTWRITEBYTECODE"] = "1";
        if (bundledPython)
        {
            psi.Environment["PYTHONNOUSERSITE"] = "1";
        }
        psi.Environment["SELFREFRESH_LANG"] = Text.Lang;
        var signing = args.Length > 0 && args[0] == "run" && ipaInfo?.Installable != true;
        if (signing)
        {
            psi.RedirectStandardInput = true;
            psi.Environment["SELFREFRESH_APPLE_ID"] = AppleIdBox.Text.Trim();
            psi.Environment["SELFREFRESH_APPLE_PASSWORD"] = PasswordBox.Password;
            var anisette = AnisetteBox.Text.Trim();
            if (anisette.Length > 0)
            {
                psi.Environment["SELFREFRESH_ANISETTE"] = anisette;
            }
        }

        await gate.WaitAsync();
        try
        {
            Process process;
            try
            {
                process = Process.Start(psi) ?? throw new InvalidOperationException("Process.Start returned null.");
            }
            catch (Exception ex)
            {
                AppendLog(Text.Format("pythonStartFailed", ("error", ex.Message)));
                AppendLog(Text.Get("pythonInstallHint"));
                return null;
            }

            running = process;
            using (process)
            {
                var logs = PumpAsync(process.StandardError);
                var stdout = process.StandardOutput.ReadToEndAsync();
                using var timeoutSource = new CancellationTokenSource(timeout);
                try
                {
                    await process.WaitForExitAsync(timeoutSource.Token);
                }
                catch (OperationCanceledException)
                {
                    CancelTwoFactor();
                    TryKill(process);
                    AppendLog(Text.Get("timedOut"));
                    try
                    {
                        await process.WaitForExitAsync();
                    }
                    catch (Exception)
                    {
                    }
                }

                await logs;
                var text = await stdout;
                return ParsePayload(text);
            }
        }
        finally
        {
            running = null;
            gate.Release();
        }
    }

    async Task PumpAsync(StreamReader reader)
    {
        try
        {
            while (true)
            {
                var line = await reader.ReadLineAsync();
                if (line == null)
                {
                    return;
                }

                if (line.StartsWith("LOG ", StringComparison.Ordinal))
                {
                    AppendLog(line[4..]);
                }
                else if (line.StartsWith("PROMPT_2FA", StringComparison.Ordinal))
                {
                    var message = line.Length > "PROMPT_2FA".Length
                        ? line["PROMPT_2FA".Length..].Trim()
                        : Text.Get("twoFactorDefault");
                    var answer = await AskTwoFactorAsync(message);
                    try
                    {
                        if (running != null && !running.HasExited)
                        {
                            await running.StandardInput.WriteLineAsync(answer);
                            await running.StandardInput.FlushAsync();
                        }
                    }
                    catch (IOException)
                    {
                    }
                    catch (InvalidOperationException)
                    {
                    }
                }
            }
        }
        catch (IOException)
        {
        }
        catch (ObjectDisposedException)
        {
        }
    }

    WorkerPayload? ParsePayload(string text)
    {
        foreach (var line in text.Split('\n').Reverse())
        {
            var trimmed = line.Trim();
            if (trimmed.Length == 0 || !trimmed.StartsWith('{'))
            {
                continue;
            }

            try
            {
                return JsonSerializer.Deserialize<WorkerPayload>(trimmed, JsonOptions);
            }
            catch (JsonException)
            {
                AppendLog(Text.Get("badResult"));
                return null;
            }
        }

        if (!string.IsNullOrWhiteSpace(text))
        {
            AppendLog(text.Trim());
        }

        return null;
    }

    void SubmitTwoFactor_Click(object sender, RoutedEventArgs e)
    {
        var code = TwoFactorCode.Text.Trim();
        if (code.Length == 0 || twoFactorWait == null)
        {
            return;
        }

        TwoFactorCode.Clear();
        TwoFactorCard.Visibility = Visibility.Collapsed;
        twoFactorWait.TrySetResult(JsonSerializer.Serialize(new { code }));
    }

    Task<string> AskTwoFactorAsync(string message)
    {
        var wait = new TaskCompletionSource<string>(TaskCreationOptions.RunContinuationsAsynchronously);
        Dispatcher.Invoke(() =>
        {
            twoFactorWait = wait;
            TwoFactorPrompt.Text = string.IsNullOrWhiteSpace(message) ? Text.Get("twoFactorDefault") : message;
            TwoFactorCode.IsEnabled = true;
            TwoFactorButton.IsEnabled = true;
            TwoFactorCard.Visibility = Visibility.Visible;
            TwoFactorCode.Focus();
        });
        return wait.Task;
    }

    void SaveAppleId_Click(object sender, RoutedEventArgs e) => SaveCurrentAccount(announce: true);

    void DeleteAppleId_Click(object sender, RoutedEventArgs e)
    {
        if (SavedAppleIdList.SelectedItem is not AccountRow selected)
        {
            AppendLog(Text.Get("deleteNone"));
            return;
        }

        var removingCurrent = SameAppleId(AppleIdBox.Text, selected.AppleId);
        accounts.RemoveAll(existing => SameAppleId(existing.AppleId, selected.AppleId));
        var next = accounts.FirstOrDefault();
        WriteAccountStore(next?.AppleId);
        ShowAccounts(next?.AppleId, fillFields: false);
        if (removingCurrent)
        {
            if (next == null)
            {
                AppleIdBox.Clear();
                PasswordBox.Clear();
                AnisetteBox.Clear();
            }
            else
            {
                ApplyAccount(next);
            }
        }

        AppendLog(Text.Get("deleted"));
    }

    void SavedAppleId_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (loadingAccounts || SavedAppleIdList.SelectedItem is not AccountRow selected)
        {
            return;
        }

        var account = accounts.FirstOrDefault(existing => SameAppleId(existing.AppleId, selected.AppleId));
        if (account == null)
        {
            return;
        }

        if (SameAppleId(AppleIdBox.Text, account.AppleId))
        {
            WriteAccountStore(account.AppleId);
            return;
        }

        ApplyAccount(account);
        WriteAccountStore(account.AppleId);
    }

    void LoadAccounts()
    {
        List<AccountRecord> loaded;
        string? selected;
        try
        {
            (loaded, selected) = ReadAccountStore();
        }
        catch (Exception ex) when (ex is IOException or JsonException or UnauthorizedAccessException)
        {
            AppendLog(Text.Get("accountsUnreadable"));
            return;
        }

        accounts.Clear();
        accounts.AddRange(loaded);
        if (selected != null && accounts.All(existing => !SameAppleId(existing.AppleId, selected)))
        {
            selected = null;
        }

        selected ??= accounts.FirstOrDefault()?.AppleId;
        ShowAccounts(selected, fillFields: selected != null);
    }

    bool SaveCurrentAccount(bool announce)
    {
        var id = NormalizeAppleId(AppleIdBox.Text);
        if (id == null)
        {
            if (announce)
            {
                AppendLog(Text.Get("appleIdEmail"));
            }

            return false;
        }

        var anisette = AnisetteBox.Text.Trim();
        if (!AnisetteLooksValid(anisette))
        {
            if (announce)
            {
                AppendLog(Text.Get("anisetteScheme"));
            }

            return false;
        }

        var existing = accounts.FirstOrDefault(account => SameAppleId(account.AppleId, id));
        var typedPassword = PasswordBox.Password;
        string protectedPassword;
        var storedNewPassword = false;
        var keptOldPassword = false;
        if (typedPassword.Length > 0)
        {
            try
            {
                protectedPassword = ProtectPassword(typedPassword);
            }
            catch (CryptographicException)
            {
                AppendLog(Text.Get("passwordProtectFailed"));
                return false;
            }

            storedNewPassword = true;
        }
        else if (!string.IsNullOrEmpty(existing?.PasswordProtected))
        {
            protectedPassword = existing.PasswordProtected;
            keptOldPassword = true;
        }
        else
        {
            protectedPassword = "";
        }

        var previous = accounts.ToList();
        accounts.RemoveAll(account => SameAppleId(account.AppleId, id));
        accounts.Insert(0, new AccountRecord
        {
            AppleId = id,
            PasswordProtected = protectedPassword,
            Anisette = anisette
        });
        if (accounts.Count > MaxSavedAccounts)
        {
            accounts.RemoveRange(MaxSavedAccounts, accounts.Count - MaxSavedAccounts);
        }

        if (!WriteAccountStore(id))
        {
            accounts.Clear();
            accounts.AddRange(previous);
            return false;
        }

        ShowAccounts(id, fillFields: false);
        if (!SameAppleId(AppleIdBox.Text, id))
        {
            AppleIdBox.Text = id;
        }

        if (announce)
        {
            if (storedNewPassword)
            {
                AppendLog(Text.Get("savedWithPassword"));
            }
            else if (keptOldPassword)
            {
                AppendLog(Text.Get("savedKeptPassword"));
            }
            else
            {
                AppendLog(Text.Get("savedNoPassword"));
            }
        }

        return true;
    }

    void ApplyAccount(AccountRecord account)
    {
        AppleIdBox.Text = account.AppleId;
        AnisetteBox.Text = account.Anisette ?? "";
        if (string.IsNullOrEmpty(account.PasswordProtected))
        {
            PasswordBox.Clear();
            return;
        }

        try
        {
            PasswordBox.Password = UnprotectPassword(account.PasswordProtected);
        }
        catch (CryptographicException)
        {
            PasswordBox.Clear();
            AppendLog(Text.Get("passwordUnlockFailed"));
        }
    }

    void ShowAccounts(string? selected, bool fillFields)
    {
        loadingAccounts = true;
        var rows = accounts.Select(account => new AccountRow
        {
            AppleId = account.AppleId,
            Label = string.IsNullOrEmpty(account.PasswordProtected) ? account.AppleId : account.AppleId + " · " + Text.Get("passwordSaved")
        }).ToList();
        SavedAppleIdList.ItemsSource = null;
        SavedAppleIdList.ItemsSource = rows;
        var match = selected == null ? null : rows.FirstOrDefault(row => SameAppleId(row.AppleId, selected));
        SavedAppleIdList.SelectedItem = match;
        loadingAccounts = false;
        if (!fillFields || match == null)
        {
            return;
        }

        var account = accounts.FirstOrDefault(existing => SameAppleId(existing.AppleId, match.AppleId));
        if (account != null)
        {
            ApplyAccount(account);
        }
    }

    (List<AccountRecord> Accounts, string? Selected) ReadAccountStore()
    {
        if (File.Exists(accountStorePath))
        {
            var store = JsonSerializer.Deserialize<AccountFile>(File.ReadAllText(accountStorePath), StoreJsonOptions) ?? new AccountFile();
            return (DistinctAccounts(store.Accounts), NormalizeAppleId(store.Selected));
        }

        if (!File.Exists(legacyAppleIdStorePath))
        {
            return ([], null);
        }

        var legacy = JsonSerializer.Deserialize<AppleIdStore>(File.ReadAllText(legacyAppleIdStorePath), StoreJsonOptions) ?? new AppleIdStore();
        var migrated = DistinctAccounts((legacy.Ids ?? []).Select(id => new AccountRecord { AppleId = id ?? "" }));
        var selected = NormalizeAppleId(legacy.Selected);
        accounts.Clear();
        accounts.AddRange(migrated);
        if (!WriteAccountStore(selected))
        {
            return (migrated, selected);
        }

        try
        {
            File.Delete(legacyAppleIdStorePath);
        }
        catch (IOException)
        {
        }

        return (migrated, selected);
    }

    static List<AccountRecord> DistinctAccounts(IEnumerable<AccountRecord>? source)
    {
        var result = new List<AccountRecord>();
        foreach (var account in source ?? [])
        {
            var id = NormalizeAppleId(account.AppleId);
            if (id == null || result.Any(existing => SameAppleId(existing.AppleId, id)))
            {
                continue;
            }

            result.Add(new AccountRecord
            {
                AppleId = id,
                PasswordProtected = account.PasswordProtected ?? "",
                Anisette = account.Anisette?.Trim() ?? ""
            });
        }

        return result;
    }

    bool WriteAccountStore(string? selected)
    {
        try
        {
            var store = new AccountFile
            {
                Accounts = accounts.ToList(),
                Selected = selected
            };
            Directory.CreateDirectory(Path.GetDirectoryName(accountStorePath)!);
            File.WriteAllText(accountStorePath, JsonSerializer.Serialize(store, StoreJsonOptions));
            return true;
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
        {
            AppendLog(Text.Get("accountWriteFailed"));
            return false;
        }
    }

    static string ProtectPassword(string password)
    {
        var protectedBytes = ProtectedData.Protect(Encoding.UTF8.GetBytes(password), AccountEntropy, DataProtectionScope.CurrentUser);
        return Convert.ToBase64String(protectedBytes);
    }

    static string UnprotectPassword(string protectedPassword)
    {
        var bytes = ProtectedData.Unprotect(Convert.FromBase64String(protectedPassword), AccountEntropy, DataProtectionScope.CurrentUser);
        return Encoding.UTF8.GetString(bytes);
    }

    static bool AnisetteLooksValid(string anisette)
    {
        if (anisette.Length == 0)
        {
            return true;
        }

        return Uri.TryCreate(anisette, UriKind.Absolute, out var uri)
            && (uri.Scheme == Uri.UriSchemeHttps || uri.Scheme == Uri.UriSchemeHttp);
    }

    static string? NormalizeAppleId(string? raw)
    {
        var text = raw?.Trim() ?? "";
        if (text.Length == 0 || !text.Contains('@') || text.IndexOf('.', text.IndexOf('@')) < 0)
        {
            return null;
        }

        return text;
    }

    static bool SameAppleId(string left, string right) =>
        string.Equals(left.Trim(), right.Trim(), StringComparison.OrdinalIgnoreCase);

    bool CredentialsReady()
    {
        if (string.IsNullOrWhiteSpace(AppleIdBox.Text) || PasswordBox.Password.Length == 0)
        {
            AppendLog(Text.Get("needCredentials"));
            return false;
        }

        if (!AnisetteLooksValid(AnisetteBox.Text.Trim()))
        {
            AppendLog(Text.Get("anisetteScheme"));
            return false;
        }

        return true;
    }

    void CancelTwoFactor()
    {
        if (!Dispatcher.CheckAccess())
        {
            Dispatcher.Invoke(CancelTwoFactor);
            return;
        }

        TwoFactorCard.Visibility = Visibility.Collapsed;
        TwoFactorCode.Clear();
        twoFactorWait?.TrySetResult("{\"abort\":true}");
        twoFactorWait = null;
    }

    void StopRunning()
    {
        CancelTwoFactor();
        if (running == null)
        {
            return;
        }

        TryKill(running);
        running = null;
    }

    static void TryKill(Process process)
    {
        try
        {
            if (!process.HasExited)
            {
                process.Kill(entireProcessTree: true);
            }
        }
        catch (InvalidOperationException)
        {
        }
    }

    void AppendLog(string message)
    {
        if (!Dispatcher.CheckAccess())
        {
            Dispatcher.Invoke(() => AppendLog(message));
            return;
        }

        if (LogBox.Text.Length > 0)
        {
            LogBox.AppendText(Environment.NewLine);
        }

        LogBox.AppendText(DateTime.Now.ToString("HH:mm:ss") + "  " + message);
        LogBox.ScrollToEnd();
    }

    static string BundleDirectory()
    {
        var candidates = new[]
        {
            AppContext.BaseDirectory,
            Path.GetDirectoryName(Environment.ProcessPath)
        };
        foreach (var dir in candidates)
        {
            if (!string.IsNullOrEmpty(dir) && File.Exists(Path.Combine(dir, "worker.py")))
            {
                return dir;
            }
        }

        return AppContext.BaseDirectory;
    }

    static string DescribeIpa(WorkerPayload info)
    {
        var state = info.Installable == true ? Text.Get("ipaSigned") : Text.Get("ipaUnsigned");
        var sharing = info.FileSharing == true ? Text.Get("fileSharingOn") : Text.Get("fileSharingOff");
        return $"{info.BundleId} · {state} · {sharing}";
    }
}

public sealed class DeviceRow
{
    public string Udid { get; init; } = "";
    public string Label { get; init; } = "";
    public string Detail { get; init; } = "";

    public static DeviceRow From(DevicePayload device)
    {
        var name = string.IsNullOrWhiteSpace(device.Name) ? "iPhone" : device.Name!;
        var ios = string.IsNullOrWhiteSpace(device.Ios) ? "" : " · iOS " + device.Ios;
        var trust = device.Paired ? Text.Get("trusted") : (string.IsNullOrWhiteSpace(device.Error) ? Text.Get("notTrusted") : device.Error!);
        return new DeviceRow
        {
            Udid = device.Udid ?? "",
            Label = name + ios,
            Detail = trust + (string.IsNullOrWhiteSpace(device.Udid) ? "" : " · " + device.Udid)
        };
    }
}

public sealed class WorkerPayload
{
    public bool? Ok { get; set; }
    public string? Status { get; set; }
    public string? Message { get; set; }
    public string? Warning { get; set; }
    [JsonPropertyName("bundle_id")]
    public string? BundleId { get; set; }
    [JsonPropertyName("display_name")]
    public string? DisplayName { get; set; }
    public bool? Signed { get; set; }
    public bool? Installable { get; set; }
    [JsonPropertyName("has_provision")]
    public bool? HasProvision { get; set; }
    [JsonPropertyName("has_signature")]
    public bool? HasSignature { get; set; }
    [JsonPropertyName("file_sharing")]
    public bool? FileSharing { get; set; }
    [JsonPropertyName("pairing_saved")]
    public string? PairingSaved { get; set; }
    public string? Output { get; set; }
    public List<DevicePayload>? Devices { get; set; }
}

public sealed class AccountRow
{
    public required string AppleId { get; init; }
    public required string Label { get; init; }
}

public sealed class AccountFile
{
    public List<AccountRecord>? Accounts { get; set; }
    public string? Selected { get; set; }
}

public sealed class AccountRecord
{
    public string AppleId { get; set; } = "";
    public string PasswordProtected { get; set; } = "";
    public string? Anisette { get; set; }
}

public sealed class AppleIdStore
{
    public List<string>? Ids { get; set; }
    public string? Selected { get; set; }
}

public sealed class DevicePayload
{
    public string? Udid { get; set; }
    public string? Name { get; set; }
    public string? Ios { get; set; }
    public bool Paired { get; set; }
    public string? Error { get; set; }
    public string? Connection { get; set; }
}
