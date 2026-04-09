<div align="center">

<img src="docs/images/icon-256.png" width="128" alt="CatWhisper Icon">

# CatWhisper

**Offline speech-to-text for macOS, right from your menu bar.**

Hold fn to speak, release to transcribe — text lands at your cursor instantly.

Fully offline. Your voice never leaves your Mac.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-macOS%2014+-black.svg)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org)
[![Apple Silicon](https://img.shields.io/badge/Apple%20Silicon-Required-green.svg)](#requirements)

[English](#features) | [繁體中文](#功能特色)

</div>

---

## Features

<table>
<tr>
<td width="50%" valign="top">

### Hold fn, just talk
No window switching, no app to open. Hold the fn key in any application, speak, and the transcription is typed at your cursor when you release.

</td>
<td width="50%" valign="top">

### Completely offline
Runs [Qwen3-ASR](https://github.com/ivan-digital/qwen3-asr-swift) and [OpenAI Whisper](https://github.com/openai/whisper) models locally via Apple MLX. Your audio data never leaves your machine.

</td>
</tr>
<tr>
<td width="50%" valign="top">

### Notch overlay
Recording and transcription status appears as a capsule near the notch with smooth spring animations. Stays out of your way.

</td>
<td width="50%" valign="top">

### Pixel cat menu bar
The pixel cat icon changes based on app state — idle (no headphones), recording (wearing headphones).

</td>
</tr>
</table>

## Requirements

| | Requirement |
|------|------|
| OS | macOS 14.0 (Sonoma) or later |
| Chip | Apple Silicon (M1 / M2 / M3 / M4) |
| Disk | ~400MB (default model, downloaded on first launch) |
| Permissions | Microphone, Accessibility (optional) |

## Install

### Download

Grab the latest `.zip` from **[Releases](https://github.com/koobraelc/CatWhisper/releases)**, unzip, and drag to Applications.

> **Note:** On first launch, right-click CatWhisper → Open to bypass Gatekeeper.

### Build from source

```bash
git clone https://github.com/koobraelc/CatWhisper.git
cd CatWhisper/CatWhisper

# Option A: Swift CLI
swift build -c release

# Option B: Xcode (requires xcodegen)
brew install xcodegen
xcodegen generate
open CatWhisper.xcodeproj
```

## Usage

```
1. Launch CatWhisper → appears in the menu bar (pixel cat icon)
2. First launch → onboarding grants Microphone & Accessibility permissions
3. Wait for model download → ~1-2 min on first run
4. Hold fn in any app → start speaking
5. Release fn → transcription is typed at your cursor
```

### Permissions

| Permission | Purpose | Required? |
|------|------|--------|
| Microphone | Record audio for transcription | Yes |
| Accessibility | Type text into other apps automatically | Optional (falls back to clipboard) |

## Models

Choose your model in Settings. Models are downloaded from Hugging Face on first use, then run fully offline.

| Model | Size | Languages | Notes |
|-------|------|-----------|-------|
| Qwen3-ASR 0.6B 4-bit | ~400MB | 30 | Default, fastest |
| Qwen3-ASR 0.6B 8-bit | ~1GB | 30 | Better accuracy |
| Qwen3-ASR 1.7B 4-bit | ~1.6GB | 52 | Balanced |
| Qwen3-ASR 1.7B 8-bit | ~2.5GB | 52 | Best accuracy |
| **Whisper large-v3-turbo** | ~1.6GB | 99 | OpenAI Whisper, widest language coverage |

## Architecture

```
CatWhisper/
├── App/
│   ├── CatWhisperApp.swift        # Entry point, MenuBarExtra
│   └── AppState.swift             # State machine (idle → recording → transcribing)
├── Audio/
│   ├── AudioRecorder.swift        # AVAudioEngine recording
│   └── AudioBuffer.swift          # Thread-safe sample buffer
├── Transcription/
│   └── TranscriptionEngine.swift  # Dual-engine: Qwen3-ASR + Whisper
├── Whisper/
│   ├── WhisperConfig.swift        # Model config from JSON
│   ├── WhisperEncoder.swift       # Conv1d + transformer audio encoder
│   ├── WhisperDecoder.swift       # Cross-attention text decoder
│   └── WhisperModel.swift         # Weight loading + greedy decoding
├── Input/
│   ├── TextInjector.swift         # Accessibility API text injection
│   └── AccessibilityChecker.swift
├── Hotkey/
│   └── FnKeyMonitor.swift         # Global fn key monitoring
├── Permissions/
│   └── PermissionManager.swift
└── UI/
    ├── MenuBarView.swift          # Menu bar popover
    ├── NotchOverlay.swift         # Dynamic Island capsule (NSPanel)
    ├── OnboardingView.swift       # First-launch wizard
    ├── SettingsView.swift         # Settings window
    └── StatusItemIcon.swift       # Pixel cat menu bar icon
```

**Built with:**
- **[MLX Swift](https://github.com/ml-explore/mlx-swift)** — ML framework for Apple Silicon
- **[Qwen3-ASR](https://github.com/ivan-digital/qwen3-asr-swift)** — On-device speech recognition
- **OpenAI Whisper** — Implemented directly in MLX Swift, no extra dependencies
- **AVAudioEngine** — Real-time audio capture
- **Accessibility API** — Cross-app text injection

## FAQ

<details>
<summary><b>fn key doesn't do anything?</b></summary>

1. Check the pixel cat icon is in the menu bar and shows "Idle"
2. Make sure the model has finished downloading (not showing "Loading model XX%")
3. System Settings → Keyboard → check fn key behavior

</details>

<details>
<summary><b>Text isn't typed automatically?</b></summary>

Grant Accessibility permission: System Settings → Privacy & Security → Accessibility → add CatWhisper.

If already granted but not working, remove CatWhisper from the list and re-add it.

</details>

<details>
<summary><b>Want better accuracy?</b></summary>

Switch to the 1.7B model or Whisper large-v3-turbo in Settings. Larger models are slower but more accurate.

</details>

<details>
<summary><b>What languages are supported?</b></summary>

Qwen3-ASR 0.6B supports 30 languages, the 1.7B variant supports 52, and Whisper large-v3-turbo supports 99. Output is converted to Traditional Chinese by default.

</details>

## Roadmap

- [ ] Custom hotkey (beyond fn)
- [ ] Language selection for transcription
- [ ] Real-time streaming transcription
- [ ] Homebrew Cask distribution
- [ ] Post-processing (punctuation, formatting)

## Contributing

Contributions welcome! See [CONTRIBUTING.md](CONTRIBUTING.md).

Bug reports, feature requests, and PRs are all appreciated.

## Credits

- [Qwen3-ASR](https://github.com/ivan-digital/qwen3-asr-swift) — Speech recognition models
- [MLX Swift](https://github.com/ml-explore/mlx-swift) — Apple ML framework
- [OpenAI Whisper](https://github.com/openai/whisper) — Speech recognition model architecture

## License

[MIT License](LICENSE) — free to use, modify, and distribute.

---

<div align="center">

# 繁體中文

</div>

## 功能特色

<table>
<tr>
<td width="50%" valign="top">

### 按住 fn，說話就好
不需要切換視窗、不需要打開 App。在任何應用程式中按住 fn 鍵說話，放開後辨識結果自動輸入到游標位置。

</td>
<td width="50%" valign="top">

### 完全離線辨識
使用 [Qwen3-ASR](https://github.com/ivan-digital/qwen3-asr-swift) 與 [OpenAI Whisper](https://github.com/openai/whisper) 模型，透過 Apple MLX 框架在本機推論。你的語音資料永遠不會離開你的電腦。

</td>
</tr>
<tr>
<td width="50%" valign="top">

### Notch 動態島狀態
錄音與辨識狀態以膠囊形式顯示在螢幕頂部 notch 旁邊，帶有流暢的 spring 動畫。不會打斷你的工作流程。

</td>
<td width="50%" valign="top">

### 像素貓選單列
Menu bar 上的像素貓圖標會隨著 App 狀態改變 — 待命時無耳機、錄音時戴上耳機。

</td>
</tr>
</table>

## 系統需求

| 項目 | 需求 |
|------|------|
| 作業系統 | macOS 14.0 (Sonoma) 或更新 |
| 處理器 | Apple Silicon (M1 / M2 / M3 / M4) |
| 磁碟空間 | ~400MB（預設模型，首次啟動自動下載） |
| 權限 | 麥克風、輔助使用（可選） |

## 安裝

### 下載安裝

前往 **[Releases](https://github.com/koobraelc/CatWhisper/releases)** 下載最新的 `.zip`，解壓後拖曳到應用程式資料夾。

> **注意：** 首次開啟時，若出現「無法驗證開發者」提示，請右鍵點擊 CatWhisper → 打開。

### 從原始碼建置

```bash
git clone https://github.com/koobraelc/CatWhisper.git
cd CatWhisper/CatWhisper

# 方法一：Swift CLI
swift build -c release

# 方法二：Xcode（需要 xcodegen）
brew install xcodegen
xcodegen generate
open CatWhisper.xcodeproj
```

## 使用方式

```
1. 啟動 CatWhisper → 出現在選單列（像素貓圖標）
2. 首次啟動 → 引導授權麥克風和輔助使用權限
3. 等待模型下載 → 首次約 1-2 分鐘
4. 在任何 App 中按住 fn → 開始說話
5. 放開 fn → 辨識結果自動輸入到游標位置
```

### 權限說明

| 權限 | 用途 | 必要性 |
|------|------|--------|
| 麥克風 | 錄製語音進行辨識 | 必要 |
| 輔助使用 | 自動將文字輸入到其他 App | 選用（未授權則複製到剪貼簿） |

## 模型

在設定中切換模型。模型首次選擇時自動從 Hugging Face 下載，之後完全離線運行。

| 模型 | 大小 | 語言數 | 說明 |
|------|------|--------|------|
| Qwen3-ASR 0.6B 4-bit | ~400MB | 30 | 預設，最快 |
| Qwen3-ASR 0.6B 8-bit | ~1GB | 30 | 較準確 |
| Qwen3-ASR 1.7B 4-bit | ~1.6GB | 52 | 平衡 |
| Qwen3-ASR 1.7B 8-bit | ~2.5GB | 52 | 最準確 |
| **Whisper large-v3-turbo** | ~1.6GB | 99 | OpenAI Whisper，語言覆蓋最廣 |

## 常見問題

<details>
<summary><b>按 fn 沒有反應？</b></summary>

1. 確認選單列有看到像素貓圖標，且狀態為「待命中」
2. 確認模型已下載完成（不是顯示「載入模型中 XX%」）
3. 檢查系統設定 → 鍵盤 → 確認 fn 鍵行為設定

</details>

<details>
<summary><b>辨識結果沒有自動輸入？</b></summary>

需要授權「輔助使用」權限。前往：系統設定 → 隱私與安全性 → 輔助使用 → 加入 CatWhisper。

若已授權仍無法使用，請先移除舊的 CatWhisper，再重新加入。

</details>

<details>
<summary><b>辨識精度不夠好？</b></summary>

可以在設定中切換到 1.7B 模型或 Whisper large-v3-turbo，精度會更高但速度稍慢。

</details>

<details>
<summary><b>支援哪些語言？</b></summary>

Qwen3-ASR 0.6B 支援 30 種語言、1.7B 支援 52 種、Whisper large-v3-turbo 支援 99 種。輸出預設轉換為繁體中文。

</details>

## 貢獻

歡迎貢獻！請參閱 [CONTRIBUTING.md](CONTRIBUTING.md)。

無論是 bug 回報、功能建議、或直接提交 PR，都非常感謝。

## 授權條款

本專案採用 [MIT License](LICENSE) 授權 — 可自由使用、修改、分發。
