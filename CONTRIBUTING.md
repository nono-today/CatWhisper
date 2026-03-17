# 貢獻指南

感謝你對 CatWhisper 有興趣！以下是參與貢獻的說明。

## 回報問題

- 使用 [Issue](https://github.com/koobraelc/CatWhisper/issues) 回報 bug 或提出功能建議
- 請附上 macOS 版本、晶片型號 (M1/M2/...)，以及重現步驟

## 開發流程

1. Fork 此 repo
2. 建立 feature branch：`git checkout -b feature/my-feature`
3. 開發並測試
4. 提交 PR 到 `main` branch

## 建置環境

- macOS 14.0+
- Xcode 15.0+
- Apple Silicon Mac

```bash
git clone https://github.com/your-username/CatWhisper.git
cd CatWhisper/CatWhisper
xcodegen generate  # 需要先 brew install xcodegen
open CatWhisper.xcodeproj
```

## 程式碼風格

- 遵循 Swift 官方 API Design Guidelines
- 使用繁體中文撰寫使用者介面文字
- 保持程式碼簡潔，避免過度抽象

## 授權

提交的程式碼將採用與本專案相同的 [MIT License](LICENSE)。
