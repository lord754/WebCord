# 🌐 WebCord

> Discord, your way — on iOS & Android.

WebCord is a client modification for Discord on **iOS and iPadOS**, based on the [Revenge](https://github.com/revenge-mod/revenge-bundle) bundle. Install plugins, themes, custom fonts, and more.

---

## ✨ Features

- 🔌 **Plugins** — extend Discord with custom features
- 🎨 **Themes & Fonts** — fully customize Discord's look
- 🧪 **Experiments** — enable hidden Discord features
- 📱 **iOS & iPadOS support** — works on iPhone and iPad
- 🔓 **No jailbreak required** — sideload via AltStore or Sideloadly

---

## ⬇️ Install

### Sideload (No Jailbreak)
Download the latest `.ipa` from [Releases](../../releases/latest) and install with:
- [AltStore](https://altstore.io)
- [Sideloadly](https://sideloadly.io)
- [TrollStore](https://github.com/opa334/TrollStore) *(if supported on your iOS version)*

### Jailbreak
| Type | File |
|------|------|
| Rootful | `*_iphoneos-arm.deb` |
| Rootless | `*_iphoneos-arm64.deb` |

---

## 🔨 Build Your Own IPA

1. Go to **Actions** → **Build & Release WebCord IPA**
2. Click **Run workflow**
3. Paste a direct link to a **decrypted Discord IPA** (from [decrypt.day](https://decrypt.day))
4. Toggle **"Publish as release"** if you want it in Releases
5. Hit **Run** — GitHub's servers build it for you (no Mac needed!)

---

## 📁 Project Structure

```
WebCord/
├── .github/workflows/build.yml   # CI/CD — builds IPA and publishes release
├── bundle/                       # Revenge JS bundle (platform-agnostic)
└── tweak/                        # iOS Logos tweak (injects bundle into Discord)
    ├── Sources/                  # Objective-C / Logos source files
    ├── Headers/                  # Header files
    ├── Makefile                  # Theos build config
    ├── control                   # Package metadata
    └── app-repo.json             # AltStore/Sidestore repo manifest
```

---

## 📜 License

BSD 3-Clause — see [LICENSE](LICENSE)

---

> Built on top of [revenge-bundle](https://github.com/revenge-mod/revenge-bundle) and [revenge-tweak](https://github.com/revenge-mod/revenge-tweak).
