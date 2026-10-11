# YT-dlp 下載小工具

以 Flutter 開發的 yt-dlp 桌面圖形介面。貼上 YouTube 影片網址、選擇儲存資料夾與輸出格式，即可下載影片或擷取音訊，並查看下載進度與執行訊息。

目前處於早期開發階段，以 **Windows** 為主要支援平台。macOS 與 Linux 已預留平台支援，尚未完成實機驗證。

## 功能

- 下載單一 YouTube 影片，支援一般影片、短網址及 Shorts 網址。
- 手動輸入儲存路徑，或透過原生視窗選擇資料夾。
- 提供自動、MP4、MKV、MP3 與 M4A 輸出選項。
- 顯示下載進度、合併／轉檔階段及執行結果。
- 啟動時檢查 yt-dlp，顯示使用中的版本與執行檔路徑。
- 同時檢查是否找到 Deno，缺少時提供提示，不阻擋下載。
- 檢查 FFmpeg 與 ffprobe 是否可執行，顯示版本、路徑或缺少工具的提示。
- 透過介面手動更新 yt-dlp，更新後重新檢查版本。

## 使用前準備

本程式呼叫外部工具，需自行準備 yt-dlp 與下載所需的相依工具。

### yt-dlp

從 [yt-dlp 官方專案](https://github.com/yt-dlp/yt-dlp) 取得適合平台的執行檔。Windows 可採用下列其中一種方式：

- 將 `yt-dlp.exe` 放在本程式的 `ydf.exe` 同一個資料夾。
- 將 `yt-dlp.exe` 所在的資料夾加入系統 `PATH`。

程式會優先使用應用程式資料夾內的 yt-dlp，找不到時才搜尋 `PATH`。若優先找到的執行檔無法使用，介面會顯示錯誤與路徑，供你確認或替換。

放入執行檔後可點選「重新檢查 yt-dlp」；修改系統 `PATH` 後，請重新啟動本程式。

### Deno（選用）

建議安裝 [Deno](https://deno.com/)，供 yt-dlp 處理 YouTube 的 JavaScript 驗證挑戰。將 `deno.exe` 所在的資料夾加入 `PATH`，或在 Windows 將它放在使用中的 `yt-dlp.exe` 同一資料夾。

程式會在檢查 yt-dlp 時一併搜尋 Deno，顯示找到的路徑或缺少工具的提示。此檢查只確認檔案存在，不驗證版本或可執行性；找不到 Deno 仍可嘗試下載，也不影響 yt-dlp 更新。放入 Deno 後可點選「重新檢查 yt-dlp」一併重新搜尋；修改 `PATH` 後請重新啟動程式。完整設定請參閱 [yt-dlp 官方 EJS 指南](https://github.com/yt-dlp/yt-dlp/wiki/EJS)。

### FFmpeg 與其他相依工具

影音合併、音訊擷取與轉檔需要 FFmpeg／ffprobe，請將兩者加入系統 `PATH`。YouTube 下載的 JavaScript runtime 與其他需求，請依使用的 yt-dlp 版本參閱 [官方相依工具說明](https://github.com/yt-dlp/yt-dlp#dependencies)。

程式啟動時會從 `PATH` 搜尋 FFmpeg 與 ffprobe，分別執行 `-version` 確認版本與可執行性；檢查逾時或工具無法使用時會顯示提示。缺少工具仍可嘗試下載，但合併、音訊擷取或轉檔可能失敗。點選「重新檢查 yt-dlp」也會重新檢查這兩個工具；修改系統 `PATH` 後請重新啟動程式。

## 使用方式

1. 啟動程式，確認 yt-dlp 顯示「已就緒」。
2. 貼上單一 YouTube 影片網址。
3. 選擇已存在且可寫入的儲存資料夾，或輸入完整絕對路徑。
4. 選擇輸出格式，點選「開始下載」。
5. 等待狀態顯示「下載完成」，並在指定資料夾查看檔案。

輸出檔名為 `影片標題 [影片 ID].副檔名`。下載進度代表目前正在下載的檔案；影音分開下載時，百分比會重新計算。下載達到 100% 後，仍可能需要合併或轉檔，請等待整個工作完成。

### 輸出格式

| 選項 | 行為 |
| --- | --- |
| 自動（不指定轉檔） | 由 yt-dlp 選擇影音格式，副檔名不固定，可能需要合併 |
| MP4 影片 | 來源容器不同時重新編碼為 MP4；已是 MP4 時可能直接保留 |
| MKV 影片 | 重新封裝為 MKV，不支援的編碼會回報失敗 |
| MP3 音訊 | 擷取音訊並輸出 MP3 |
| M4A 音訊 | 擷取音訊並輸出 M4A |

MP4 選項未指定 H.264 等特定編碼，播放相容性仍取決於來源與處理結果。目前畫質由 yt-dlp 自動選擇。

### 更新 yt-dlp

點選工具狀態旁的「更新 yt-dlp」按鈕，可對目前使用的執行檔執行自我更新。更新沿用該執行檔的更新通道，結果顯示在執行狀態區域。

透過 pip 或其他套件管理器安裝的版本，可能需要使用原本的安裝工具更新。若更新失敗，請查看執行訊息與 [yt-dlp 官方更新說明](https://github.com/yt-dlp/yt-dlp#update)。

## 目前限制

- 同一時間只能執行一個下載或更新工作。
- 尚未支援取消下載、播放清單、批次佇列、直播、登入／Cookie 管理及排程。
- 尚未提供工具自動安裝、背景更新或設定保存。
- 執行時忽略外部 yt-dlp 設定檔，使用介面指定的選項。
- 執行狀態區域保留最近 200 行訊息。

## 開發

Flutter 專案與 Dart 套件名稱為 `ydf`。狀態管理使用 Riverpod，不使用程式碼產生功能。

需準備 Windows 桌面開發環境，以及包含 Dart `^3.13.2` 的 Flutter SDK。在專案根目錄執行：

```sh
flutter pub get
flutter run -d windows
```

開發模式下，若要使用隨程式放置的 yt-dlp，可將 `yt-dlp.exe` 放入 `build/windows/x64/runner/Debug/`。

### 檢查與測試

```sh
flutter analyze
flutter test
```

另有使用本機 HTTP 影片來源的選擇性整合測試，可驗證五種輸出格式、進度回報與重複下載行為。在 PowerShell 設定實際工具路徑後執行：

```powershell
$env:YDF_INTEGRATION_YTDLP = 'C:\tools\yt-dlp.exe'
$env:YDF_INTEGRATION_FFMPEG = 'C:\tools\ffmpeg.exe'
flutter test test/integration/yt_dlp_local_test.dart
```

FFmpeg／ffprobe 亦需可由 `PATH` 找到。未設定上述環境變數時，這些整合測試會略過；測試不會下載 YouTube 影片或更新已安裝的 yt-dlp。

### 建置 Windows 版本

```sh
flutter build windows --release
```

建置結果位於 `build/windows/x64/runner/Release/`。分發時請保留整個輸出資料夾，包含 DLL 與 `data/` 等執行所需檔案。

### GitHub Actions

每次 push、pull request 或手動觸發 CI 時，會在 Windows 執行靜態分析、測試與 Release 建置。CI 固定使用 Flutter `3.47.2`；升級 SDK 時請同步調整 `.github/workflows/ci.yml`。

執行成功後，可在該次 Actions 頁面的 Artifacts 下載 `ydf-windows-x64`，保留 14 天。產物包含完整應用程式資料夾；yt-dlp、Deno 與 FFmpeg 需自行準備。CI 未設定實機整合測試的工具路徑，這些測試會略過。

## 問題回報

回報問題時，請提供作業系統、yt-dlp 版本、選擇的輸出格式、重現步驟，以及執行狀態區域中的相關錯誤訊息。貼上紀錄前，請先移除個人資料與不希望公開的路徑。

## License

```
Copyright 2026 少年ウィンド

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```
