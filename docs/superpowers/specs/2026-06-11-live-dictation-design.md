# CatWhisper 即時聽寫（邊講邊出字）設計

日期：2026-06-11
狀態：已由使用者核准（對話中逐項確認）

## 目標

按住 fn 講話時，辨識文字即時打進目前 focused 的視窗（不是浮窗預覽），
放開 fn 後補上最終結果。維持既有「按住 fn」操作方式。

## 使用者決策

| 決策 | 選擇 |
|------|------|
| 文字出現位置 | 直接打進目標視窗（delta 注入） |
| 觸發方式 | 維持按住 fn |
| 串流引擎 | NemotronStreamingASR（原生 zh-TW，CoreML INT8，~600MB 一次性下載） |

## 架構

既有批次路徑（Qwen3/Whisper → 放開才貼上）完全保留；
選擇 Nemotron 串流模型時走新路徑：

```
fn 按下
  └─ AudioRecorder（加 onSamples callback）→ 16kHz Float 區塊
       └─ NemotronStreamingEngine (actor)
            ├─ 緩衝 ≥0.2s 即 session.pushAudio() → PartialTranscript[]
            ├─ 組合 committed(isFinal) + 最新 partial → 完整假設字串
            ├─ 簡→繁轉換
            └─ 假設字串 → LiveTextInjector.update()
                 ├─ 與已注入文字取共同前綴（TextDelta 純函式）
                 ├─ 需要修正 → N 個 backspace
                 └─ CGEvent unicode 直接打字（不經剪貼簿）
fn 放開
  └─ engine.finish()：push 殘餘音訊 + finalize() → 最終文字
       └─ injector 補最後 delta → 寫入歷史記錄
```

## 元件

1. **`TextDelta`**（純函式，`Input/LiveTextInjector.swift`）
   `(injected: String, hypothesis: String) -> (backspaces: Int, insert: String)`
   以 Character（grapheme cluster）為單位比對，避免 emoji/組合字截斷。有單元測試。
2. **`LiveTextInjector`**（`Input/`）
   維護已注入文字狀態；`update(hypothesis:)` 套 TextDelta，
   backspace 用 kVK_Delete 鍵事件、插入用 `keyboardSetUnicodeString`（每事件 ≤20 UTF-16 單元分段）。
   只在假設改變時動作；節流由上游 0.2s 推送週期天然保證。
3. **`NemotronStreamingEngine`**（actor，`Transcription/`）
   `loadModel(progressHandler:)`、`startSession(language: "zh-TW")`、
   `feed(_ samples:)`、`finish() -> String`。內部緩衝音訊、聚合 segments。
4. **`AudioRecorder`** — tap 內加 `onSamples: (([Float]) -> Void)?`，
   批次路徑不受影響（callback 為 nil）。
5. **`AppState`** — `ModelFamily` 加 `.nemotronStreaming`（id 含 "nemotron" 判定）；
   串流路徑跳過 0.3s 最短錄音檢查（部分文字可能已注入，不可丟棄）。
6. **`SettingsView`** — 模型選單新增
   「即時聽寫 — Nemotron 0.6B（多語含中文，~600MB）」
   tag：`aufklarer/Nemotron-3.5-ASR-Streaming-0.6B-CoreML-INT8`。

## 錯誤處理 / 已知限制

- 無輔助使用權限 → 該次自動退回批次模式（錄完放剪貼簿）並顯示既有提示。
- 聽寫中切換視窗：文字跟著打進新視窗（即時注入的本質限制，不處理）。
- 攔截按鍵的 app（vim、密碼欄）行為可能異常：使用者按住 fn 自主控制，風險可接受。
- 串流途中辨識錯誤 → 停止 session、顯示既有 error state、已注入文字保留。

## 測試

- `TextDelta` 純函式：以 swiftc 編譯獨立測試腳本驗證（專案無測試 target，
  MLX 依賴使 swift test 不可用）。案例：追加、前綴修正、全部重打、
  中文 grapheme、空字串雙向。
- 端到端：實機按住 fn 講話驗證即時出字與最終修正。
