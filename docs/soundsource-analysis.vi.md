# SoundSource: phân tích REA và hướng xây dựng My Sound Control

Ngày nghiên cứu: 13/11/2026.

## Kết luận

Có cơ sở kỹ thuật để xây dựng app macOS độc lập có các nhóm chức năng tương tự SoundSource. Phần cốt lõi là engine thu và phát lại âm thanh theo ứng dụng, quản lý thay đổi thiết bị và xử lý DSP trong luồng thời gian thực. Giao diện menu bar chỉ là một phần của sản phẩm.

Đề xuất dùng Swift/AppKit cho ứng dụng, Core Audio cho thiết bị và process taps, C/C++ hoặc callback được kiểm soát chặt cho xử lý audio, Audio Units cho hiệu ứng. Ưu tiên chứng minh đường audio hoạt động trước khi xây dựng đầy đủ giao diện. Không thể kết luận đã đạt tương đương toàn bộ SoundSource từ phân tích tĩnh này.

Phạm vi là viết lại tính năng bằng mã riêng. Không sử dụng lại framework, asset, tên hiệu ứng thương mại hay cơ chế cấp phép của SoundSource trong sản phẩm mới.

## 1. Mẫu đã phân tích

Không tìm thấy SoundSource tại `/Applications/SoundSource.app` hoặc `~/Applications/SoundSource.app`. Đã tải bản phân phối chính thức qua:

- https://rogueamoeba.com/soundsource/download.php
- Trang sản phẩm: https://rogueamoeba.com/soundsource/
- Manual: https://rogueamoeba.com/support/manuals/soundsource?print=true

Thông tin mẫu:

| Thuộc tính | Giá trị | Nguồn |
|---|---|---|
| Version/build | 6.2.0 / 6.2.0 | Info.plist, đọc bằng Python plistlib |
| Bundle ID | com.rogueamoeba.soundsource | Info.plist |
| Minimum macOS | 15.0 | Info.plist |
| Menu bar app | LSUIElement = true | Info.plist |
| Kiến trúc REA chọn | arm64 | REA open_binary |
| SHA-256 ZIP | e0d63ca156d1606127b2cda84e6a47702830859712b48ccce5395172c00663bf | REA |
| SHA-256 main executable | b05be14debd1355f88868715279b25c8ee2cb2931ef11537aa85c93517997eb3 | REA |
| SHA-256 SSAudio | 510e2df9183256546bf11518e2c66622597f9e288c2129d167f5b0e420d7ca79 | REA |

REA kiểm kê container với 609 nodes, 675 occurrences, 616 edges. Đây là các đối tượng trong artifact graph, không phải số file mã nguồn.

Không chạy SoundSource, không cài helper hoặc audio component, không thay đổi thiết bị âm thanh của máy.

## 2. Công cụ REA và giới hạn bằng chứng

Các bước đã thực hiện:

1. `binary_session`: kiểm tra khả năng phân tích của môi trường.
2. `open_binary`: mở ZIP chính thức.
3. `inspect_artifact`: kiểm kê artifact và tính hash.
4. `extract_artifact`: giải nén vào thư mục tạm do REA quản lý.
5. `open_binary` + `inspect_native_dispatch_metadata`: đọc metadata main executable và SSAudio.framework.
6. `export_evidence_bundle`: lưu bằng chứng đầy đủ.

Main executable có 688 Objective-C class records, gồm 344 records không phải metaclass. SSAudio có 43 records không phải metaclass. Các con số này không đại diện cho toàn bộ type Swift hoặc tổng số lớp trong mọi framework.

Các giới hạn quan trọng:

- Ghidra chưa cấu hình; Hopper chưa cài ở đường dẫn REA tìm kiếm; IDA chưa đăng ký. Chưa có decompile thân hàm hoặc call graph sâu.
- Metadata main executable đạt giới hạn `max_records=20000`; một số ivar, Swift conformance/vtable không giải được. SSAudio cũng có các facet partial/unsupported.
- Kết quả metadata main vượt giới hạn trả về của MCP, nhưng REA đã giữ bản đầy đủ và xuất thành công. Bằng chứng vẫn có giới hạn coverage của phép phân tích ban đầu.
- `inspect_macho` và `inspect_plist` thất bại với lỗi native utility `file`, reason `io`, cả MCP lẫn CLI. Đọc Info.plist bằng Python là phương án phụ; không ghi nhận các lệnh REA này là thành công.
- Không suy ra thuật toán DSP, luồng gọi hoặc cơ chế IPC chính xác chỉ từ tên lớp và selector.
- Chưa xác minh chữ ký mã, hành vi runtime, chất lượng âm thanh hay độ trễ.

File `research/rea-evidence.json` chứa 5 records bằng chứng. `research/rea-structure-summary.json` là bản rút gọn tên lớp/phương thức, thuận tiện đọc hơn. Trường `unknowns` trống của bundle không có nghĩa ứng dụng đã được phân tích hoàn toàn; phải đọc `coverage` trong từng record.

## 3. Những thành phần quan sát được

### Mô hình nguồn và graph

Các lớp và selector có trong metadata main executable:

| Lớp | Selector tiêu biểu | Ý nghĩa có thể suy ra |
|---|---|---|
| SSModelSource | `captureUID`, `updateTapModel`, `processingEffectsLatency`, `sharedGraphHostDevice`, `modifiesAudioOn:hasProcessingEffects:` | Mô hình nguồn gắn với capture, hiệu ứng và graph |
| SSAppModelSource | `processes`, `captureReferences`, `capturesIfPlayingOn:`, `shouldEnableCaptureWithDevice:` | Một nguồn app có thể liên hệ nhiều process/capture references |
| SSGraphController | `sourceNodes`, `effectNodes`, `updateGraphWithConfig:fingerprint:error:`, `stopAndDeleteGraph` | Quản lý vòng đời graph và tập node |
| VolumeController | `effectiveVolume`, `tapVolume`, `routeVolume`, `muteTimer` | Tách trạng thái volume hiệu dụng, tap, route và mute timer |
| DeviceSelectionController | `deviceSelectionHistory`, `matchDeviceHistoryWithForce:completionHandler:` | Lưu lựa chọn thiết bị và xử lý thay đổi |
| SSOutputGroup | `devices`, `_updateVADWithCompletionHandler:`, `refreshAfterAudiodRestart`, `destroyDevice` | Quản lý nhóm thiết bị và phục hồi vòng đời audio |
| SSQuickConfig / SSPreset | Có trong metadata | Lớp cấu hình và preset riêng |

Cột ý nghĩa là diễn giải kiến trúc từ metadata, chưa phải kết quả trace thân hàm. Ví dụ tên `_updateVAD...` chưa chứng minh loại virtual device hoặc API nội bộ được dùng.

### Thành phần audio

Trong SSAudio.framework có các lớp:

- `SSAudioProcessManager`, `SSAudioProcess`: quản lý process theo tên metadata.
- `SSAudioTap`, `SSTap`, `SSAudioTapContext`: context có `willStartIO`, `didStopIO`, `processIO:buffer:`; SSTap có `start`/`stop`.
- `SSAudioTapGraph`, `SSAudioTapProcessor`, `SSAudioTapProcessorPool`: các thành phần graph và xử lý tap.
- `SSAudioMixBuffer`, `SSMixQueue`, `SSAudioVolumeSmoother`: buffer, queue và làm mượt volume theo tên lớp.
- `SSAudioMeter`: `clipStereoMax`, `peakStereoMax`, `rmsStereoMax`.
- `SSAudioMediaKeyListener`: bật/tắt, event callback, health check và restart.
- `SSAudio`: thuộc tính `tapsEnabled`, `metersEnabled`, `sampleRate`, `multiChannel`, `directOutputGroupFanout`.

Các lớp này cho thấy các mối quan tâm mà engine mới cần giải quyết, nhưng chưa chứng minh SoundSource sử dụng chính xác Core Audio Process Taps công khai trên mọi đường xử lý.

### Framework và helper trong gói

Quan sát trực tiếp tên file/framework:

- `ACENode`, `ACP`, `ARKManager`, `AudioHijackKit2`, `GraphKit`, `NodeKit`, `SSAudio`.
- `RAAudioUnit`, `RemoteAU`, `auverse`; RemoteAU chứa `RemoteAUHost.xpc` cùng host launcher.
- `APEnabler`, `APERouteService.app`, `APERoutePicker.xpc`, `MediaRemoteAdapter`.
- `SoundSource Proxy Player`, `arkinstaller`.
- `GX`, `Protein`, `Permissions`, `QuickTour` và Sparkle lồng trong Protein.

Sự hiện diện của host XPC hỗ trợ nhận định sản phẩm tách một số tác vụ thành tiến trình phụ. Chưa xác định đầy đủ hợp đồng IPC hoặc chính sách phục hồi crash. Không đưa các binary này vào app mới.

## 4. Tính năng mục tiêu theo manual chính thức

| Nhóm | Hành vi cần có | Hướng triển khai độc lập / khó khăn |
|---|---|---|
| System devices | Chọn output, input, sound effects; volume, mute, sample rate | Core Audio HAL; kiểm tra khả năng đọc/ghi từng property của từng thiết bị |
| Per-app mixer | Volume/mute, meter, favorites, app đang phát và vừa phát | Process inventory + taps; ánh xạ browser helper và process thay PID |
| Per-app routing | Mỗi app phát qua output riêng | Thu tap, xử lý và phát lại; mute luồng gốc để tránh tiếng kép |
| Gain trên 100% | Manual mô tả Volume Overdrive tối đa 400% ở từng app | Gain + limiter riêng; không giả định khôi phục được tín hiệu đã clip |
| Dynamic boost | Tăng đoạn nhỏ, kiểm soát đoạn lớn | Compressor/automatic gain + limiter; thiết kế và nghe thử thuật toán riêng |
| EQ | EQ 10 băng, preset, bypass, thứ tự hiệu ứng | Audio Unit EQ hoặc DSP riêng; kiểm soát headroom và smoothing |
| Balance / pan | Điều chỉnh stereo | DSP riêng và kiểm thử multichannel |
| Headphone EQ | Profile tai nghe; nhập profile riêng | Profile người dùng hoặc nguồn cho phép sử dụng; kiểm tra license dữ liệu riêng |
| Audio Units | Thêm plugin, editor và lưu preset | Host AU; cô lập plugin lỗi, tương thích AU/kiến trúc |
| Timed mute | 30 giây, 1 phút, 2 phút, fade trở lại | Scheduler + trạng thái monotonic + gain ramp |
| Quick configs | Lưu thiết bị, volume, hiệu ứng và thiết lập từng app | Model Codable có version; xử lý thiết bị/plugin thiếu |
| Output groups | Phát nhiều thiết bị, volume từng thành viên | Aggregate/fanout, sample conversion, clock drift và bù latency |
| AirPlay | Gửi từng app hoặc nhóm tới loa AirPlay | Cần spike riêng; chưa chứng minh public API đạt tương đương chức năng SoundSource |
| Điều khiển | Menu bar, compact, pin window, hotkey, media keys, Shortcuts | NSStatusItem/NSPanel + App Intents; xin quyền theo tính năng thực dùng |
| Cá nhân hóa | Thứ tự app, nickname thiết bị, icon, cấu hình riêng | Lớp preference độc lập với audio callback |

Manual mô tả danh sách giữ app vừa phát trong 60 giây. Bản đầu có thể dùng hành vi này hoặc cho người dùng tùy chỉnh.

## 5. API Apple có thể dùng

Đã đọc tài liệu Apple về Core Audio taps:

- https://developer.apple.com/documentation/coreaudio/capturing-system-audio-with-core-audio-taps
- https://developer.apple.com/documentation/coreaudio/catapdescription

Apple mô tả tap thu output của một hoặc nhiều process, có mixdown mono/stereo; tap có thể mute output gốc và đưa âm thanh vào tap. Tap được gắn làm input của HAL aggregate device cấu hình cho playback. Sample yêu cầu macOS 14.2 trở lên và `NSAudioCaptureUsageDescription`; hệ thống hỏi quyền thu âm hệ thống khi bắt đầu capture.

Không dùng mốc availability của một trang metadata đơn lẻ để khẳng định mọi API hoạt động trên cùng phiên bản. Đề xuất baseline ban đầu macOS 15+ và kiểm tra availability từng API khi triển khai.

Đường audio đề xuất, chưa được chạy thử:

```text
App/process audio
  → process tap (mute output gốc khi pipeline sẵn sàng)
  → buffer có timestamp / chuyển đổi sample rate khi cần
  → gain ramp → EQ / AU effects → limiter
  → output đã chọn
  → meter snapshot đưa sang UI với tần suất giới hạn
```

Callback audio tránh cấp phát động, khóa chặn, truy cập file, log và cập nhật UI. Đổi cấu hình phải được chuyển giao an toàn từ control thread. Khi tap/output thất bại cần trả lại âm gốc và dọn resource; phải kiểm chứng thực tế cả tình huống app crash.

## 6. Lộ trình thực hiện và tiêu chí hoàn thành

### Bước 1: Chứng minh engine theo từng app

Làm một harness nhỏ trước giao diện đầy đủ:

- Liệt kê audio devices và process; chọn một app đang phát.
- Thu tap → gain/mute → một output; volume thay đổi có ramp.
- Tách quyền bị từ chối khỏi lỗi thiết bị và lỗi format.
- Cleanup khi stop, process thoát, thay output; kiểm tra khi engine crash.

Chỉ đạt bước này khi nghe và đo xác nhận không có tiếng kép, không feedback, volume thực sự thay đổi độc lập; báo cáo latency, sample rate và thiết bị thử. Thử hai app cùng lúc để chứng minh độc lập. Kiểm tra thêm browser nhiều process, sleep/wake và Bluetooth reconnect.

### Bước 2: Mixer dùng hằng ngày

Menu bar UI, system devices, favorites, timed mute, routing theo app, nhớ thiết bị bằng UID và preference theo bundle ID; hotkey, cấu hình khởi động cùng máy. Cần phục hồi sau restart dịch vụ audio và fallback khi thiết bị biến mất.

### Bước 3: DSP và cá nhân hóa

EQ, limiter, boost thuật toán riêng, balance/pan, preset, quick configs, UI tùy chỉnh. Kiểm tra clipping, ramp, stereo, silence, sample-rate change và nghe A/B trên nhiều nguồn âm.

### Bước 4: Nhóm thiết bị, AU và AirPlay

Mỗi hạng mục cần spike độc lập và tiêu chí tương thích. Đo drift/latency khi output có clock khác nhau. Plugin AU lỗi phải có khả năng khôi phục. Chưa hứa tương đương AirPlay đa thiết bị trước khi xác minh API và đồng bộ.

## 7. Trạng thái tại thời điểm kết thúc nghiên cứu ban đầu

Đây là snapshot trước bước triển khai. Trạng thái mã nguồn và kiểm thử mới hơn nằm ở README.md và validation.md.

- Hoàn thành nghiên cứu tính năng, kiểm kê bằng REA, metadata main và SSAudio, lưu evidence và kiến trúc đề xuất.
- Chưa tạo mã app; chưa build, test DSP, thử quyền capture hoặc nghe runtime.
- `xcrun --show-sdk-path` hiện bị chặn bởi giấy phép Xcode chưa được chấp nhận. Cần người dùng tự đọc/chấp nhận giấy phép Xcode trước bước build với SDK Apple.
- Chưa khởi tạo Git hoặc CodeGraph; nghiên cứu này phân tích artifact, không thực hiện tra cứu symbol trong source project.
- Skill `swiftpm-macos` đã được đọc để đánh giá phương án build sau này; chưa áp dụng quy trình build trong lượt nghiên cứu này.
