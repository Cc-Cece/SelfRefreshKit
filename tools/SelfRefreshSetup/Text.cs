using System.ComponentModel;
using System.Globalization;
using System.IO;
using System.Reflection;
using System.Text.Json;

namespace SelfRefreshSetup;

public static class Text
{
    public static string Lang { get; private set; } = "en";

    public static event Action? LanguageChanged;

    public static readonly LanguageChoice[] Languages =
    [
        new() { Code = "zh-CN", Label = "简体中文" },
        new() { Code = "zh-TW", Label = "繁體中文（台灣）" },
        new() { Code = "zh-HK", Label = "廣東話（香港）" },
        new() { Code = "ja", Label = "日本語" },
        new() { Code = "en", Label = "English" },
    ];

    static readonly Dictionary<string, Dictionary<string, string>> Catalog;
    static readonly Dictionary<string, Phrase> Phrases = new(StringComparer.Ordinal);
    static readonly string[] Supported = ["en", "zh-CN", "zh-HK", "zh-TW", "ja"];
    static readonly JsonSerializerOptions LanguageJson = new()
    {
        PropertyNameCaseInsensitive = true,
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        WriteIndented = true
    };

    static Text()
    {
        Catalog = Load();
        Lang = ReadSavedLanguage() ?? Resolve(CultureInfo.CurrentUICulture);
        Environment.SetEnvironmentVariable("SELFREFRESH_LANG", Lang);
    }

    public static Phrase PhraseFor(string key)
    {
        if (!Phrases.TryGetValue(key, out var phrase))
        {
            phrase = new Phrase(key);
            Phrases[key] = phrase;
        }

        return phrase;
    }

    public static bool SetLanguage(string raw)
    {
        var canonical = Canonical(raw);
        if (canonical == null || canonical == Lang)
        {
            return true;
        }

        Lang = canonical;
        Environment.SetEnvironmentVariable("SELFREFRESH_LANG", Lang);
        var saved = SaveLanguage(Lang);
        foreach (var phrase in Phrases.Values)
        {
            phrase.Refresh();
        }

        LanguageChanged?.Invoke();
        return saved;
    }

    public static string Get(string key)
    {
        if (Catalog.TryGetValue(key, out var entry))
        {
            if (entry.TryGetValue(Lang, out var value) && value.Length > 0)
            {
                return value;
            }

            if (entry.TryGetValue("en", out var english) && english.Length > 0)
            {
                return english;
            }
        }

        return key;
    }

    public static string Format(string key, params (string Name, string Value)[] args)
    {
        var text = Get(key);
        foreach (var (name, value) in args)
        {
            text = text.Replace("{" + name + "}", value, StringComparison.Ordinal);
        }

        return text;
    }

    public static string Resolve(CultureInfo culture)
    {
        var forced = Environment.GetEnvironmentVariable("SELFREFRESH_LANG");
        if (!string.IsNullOrWhiteSpace(forced))
        {
            return Canonical(forced) ?? "en";
        }

        for (var current = culture; !string.IsNullOrEmpty(current.Name); current = current.Parent)
        {
            var match = MatchCulture(current.Name);
            if (match != null)
            {
                return match;
            }
        }

        return "en";
    }

    static string? Canonical(string? raw)
    {
        if (string.IsNullOrWhiteSpace(raw))
        {
            return null;
        }

        foreach (var lang in Supported)
        {
            if (string.Equals(raw.Trim(), lang, StringComparison.OrdinalIgnoreCase))
            {
                return lang;
            }
        }

        return null;
    }

    static string? MatchCulture(string name)
    {
        if (name is "zh-HK" or "zh-MO" or "zh-Hant-HK" or "zh-Hant-MO" || name.StartsWith("yue", StringComparison.OrdinalIgnoreCase))
        {
            return "zh-HK";
        }

        if (name is "zh-TW" or "zh-Hant" or "zh-CHT" or "zh-Hant-TW")
        {
            return "zh-TW";
        }

        if (name is "zh-CN" or "zh-SG" or "zh-Hans" or "zh-Hans-CN" or "zh-Hans-SG" or "zh")
        {
            return "zh-CN";
        }

        if (name.StartsWith("ja", StringComparison.OrdinalIgnoreCase))
        {
            return "ja";
        }

        if (name.StartsWith("en", StringComparison.OrdinalIgnoreCase))
        {
            return "en";
        }

        return null;
    }

    static Dictionary<string, Dictionary<string, string>> Load()
    {
        using var stream = Assembly.GetExecutingAssembly().GetManifestResourceStream("SelfRefreshSetup.i18n.json");
        if (stream == null)
        {
            return [];
        }

        var catalog = JsonSerializer.Deserialize<Dictionary<string, Dictionary<string, string>>>(stream);
        return catalog ?? [];
    }

    static string? ReadSavedLanguage()
    {
        try
        {
            var path = LanguagePath();
            if (!File.Exists(path))
            {
                return null;
            }

            var file = JsonSerializer.Deserialize<LanguageFile>(File.ReadAllText(path), LanguageJson);
            return Canonical(file?.Lang);
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException or JsonException)
        {
            return null;
        }
    }

    static bool SaveLanguage(string lang)
    {
        try
        {
            var path = LanguagePath();
            Directory.CreateDirectory(Path.GetDirectoryName(path)!);
            File.WriteAllText(path, JsonSerializer.Serialize(new LanguageFile { Lang = lang }, LanguageJson));
            return true;
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
        {
            return false;
        }
    }

    static string LanguagePath() => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "SelfRefreshSetup",
        "language.json");

    sealed class LanguageFile
    {
        public string? Lang { get; set; }
    }
}

public sealed class LanguageChoice
{
    public string Code { get; init; } = "";
    public string Label { get; init; } = "";

    public override string ToString() => Label;
}

public sealed class Phrase : INotifyPropertyChanged
{
    public Phrase(string key) => Key = key;

    public string Key { get; }

    public string Value => Text.Get(Key);

    public event PropertyChangedEventHandler? PropertyChanged;

    public void Refresh() => PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(nameof(Value)));
}
