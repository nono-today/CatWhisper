# CatWhisper

macOS 選單列語音轉文字工具。按住 fn 說話，放開自動辨識並輸入文字。

全程離線，使用 [Qwen3-ASR](https://github.com/ivan-digital/qwen3-asr-swift) 模型在本機運行，無需雲端 API。

## 功能

- **按住 fn 錄音** — 放開即辨識，結果直接輸入到游標所在位置
- **完全離線** — 模型在本機 Apple Silicon 上用 MLX 推論，資料不離開你的電腦
- **Notch 動態島** — 錄音、辨識、結果狀態顯示在螢幕頂部 notch 旁
- **Nyan Cat 選單列圖標** — 不同狀態有不同表情（待命 / 錄音 / 辨識 / 錯誤）
- **辨識歷史** — 最近 50 筆紀錄，隨時複製
- **繁體中文** — 介面與辨識結果皆為繁體中文

## 系統需求

- macOS 14.0 (Sonoma) 或更新
- Apple Silicon (M1/M2/M3/M4)
- 約 400MB 磁碟空間（模型會在首次啟動時自動下載）

## 安裝

### 下載

前往 [Releases](https://github.com/koobraelc/CatWhisper/releases) 下載最新的 `.dmg`，拖曳到應用程式資料夾即可。

### 從原始碼建置

```bash
git clone https://github.com/koobraelc/CatWhisper.git
cd CatWhisper/CatWhisper
```

**用 Xcode 開啟：**

```bash
open CatWhisper.xcodeproj
```

或透過 xcodegen 重新產生專案：

```bash
brew install xcodegen
xcodegen generate
open CatWhisper.xcodeproj
```

**用命令列建置：**

```bash
xcodebuild build \
  -scheme CatWhisper \
  -configuration Release \
  -destination 'platform=OS X' \
  -skipPackagePluginValidation
```

## 使用方式

1. 啟動 CatWhisper — 會出現在選單列（Nyan Cat 圖標）
2. 首次啟動會引導授權**麥克風**和**輔助使用**權限
3. 等待模型下載完成（首次約需 1-2 分鐘）
4. 在任何 App 中按住 **fn** 鍵開始說話
5. 放開 fn 鍵，辨識結果會自動輸入到游標位置

## 權限說明

| 權限 | 用途 |
|------|------|
| 麥克風 | 錄製語音 |
| 輔助使用 | 將辨識結果自動輸入到其他 App（若不授權，會改為複製到剪貼簿） |

## 模型選擇

在設定中可以切換：

| 模型 | 大小 | 說明 |
|------|------|------|
| Qwen3-ASR 0.6B (4-bit) | ~400MB | 預設，速度快 |
| Qwen3-ASR 1.7B (8-bit) | ~2.5GB | 更高精度 |

## 授權條款

本專案採用 [MIT License](LICENSE) 授權。

## 貢獻

歡迎貢獻！請參閱 [CONTRIBUTING.md](CONTRIBUTING.md)。
