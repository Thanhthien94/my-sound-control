# My Sound Control

Ứng dụng macOS độc lập để cá nhân hóa âm thanh bằng SwiftUI, Core Audio Process Taps và callback C. Không sử dụng binary hoặc asset của SoundSource.

- [Phân tích SoundSource bằng REA](docs/soundsource-analysis.vi.md)
- [Bằng chứng và nguồn nghiên cứu](docs/research/)

## 0.1.0-preview.4

Logo waveform/fader theo palette SkyTruong, cùng phong cách My Fan Control; bộ icon macOS và logo trong cửa sổ mixer đã tích hợp.

- EQ stereo 10 băng riêng cho từng app, 31 Hz–16 kHz, ±12 dB, bước 0,5 dB; bật/bypass và đặt lại.
- Preset Phẳng, Âm trầm, Giọng nói, Trong sáng, Êm dịu; lưu cấu hình tùy chỉnh theo app.
- Preamp −24…0 dB, tự bù headroom và báo cắt đỉnh; chuyển cấu hình bằng crossfade 20 ms. [Chi tiết EQ](docs/equalizer.md).

- Tạm tắt tiếng từng app trong 30 giây, 1 phút hoặc 2 phút; đếm ngược và bật tiếng ngay. Hết giờ khôi phục volume hiện tại qua gain ramp có sẵn.
- Cài đặt khởi động cùng macOS qua ServiceManagement, mặc định tắt. Mở bản trong Applications để thay đổi; Mixer vẫn bật thủ công.
- Hẹn giờ chỉ thuộc phiên hiện tại; tắt Mixer, đổi đầu ra, sleep hoặc thoát app sẽ hủy hẹn giờ và trả âm gốc.

- Menu bar và cửa sổ mixer tiếng Việt; không có icon Dock.
- Chọn thiết bị output, microphone, thông báo; volume/mute phần cứng khi có master control.
- Mixer từng audio process: volume 0–100%, mute, meter, chọn đầu ra.
- Favorites và lưu thiết lập cục bộ; không tự bật lại capture sau mỗi lần mở app.
- Gain ramp 5 ms; callback C không cấp phát/khóa/log. Dừng phiên khi buffer, thiết bị hoặc process thay đổi.

Preview giới hạn Float32 stereo input, mono/stereo output cùng sample rate. Thiết bị duplex/multichannel có thể bị từ chối; browser helper có thể hiện thành process riêng. Chưa dynamic boost/AU/hotkeys/AirPlay đa thiết bị. DSP tests không thay thế thử audio thực tế.

## Build và chạy

macOS 15+, Swift 6+. Kiến trúc phát hành preview: Apple Silicon.

```sh
./script/test.sh
./script/build_and_run.sh --verify
```

Run button của Codex gọi script build/run. Các mode khác: `--build-only`, `--debug`, `--logs`, `--telemetry`. Bundle ký ad-hoc tại `dist/MySoundControl.app`. Script ưu tiên CLT, không thay đổi xcode-select; cho phép chọn `MSC_DEVELOPER_DIR`/`MSC_SDK_PATH`. Máy hiện tại dùng CLT + SDK 26.5 do SDK 27.2 thiếu SwiftUI macro plugin.

Lần đầu bật Mixer cần quyền ghi âm hệ thống. Đóng cửa sổ vẫn để app chạy trong menu bar; chọn Thoát để dừng hoàn toàn.

## Phát hành

Theo luồng my-fan-control: version preview → test → commit sạch → release build arm64 → DMG/ZIP/SHA256 → GitHub prerelease. Ký ad-hoc, chưa notarize.

- [Cài app](INSTALL.md)
- [Quy trình release](docs/releasing.md)
- [Kết quả kiểm chứng](docs/validation.md)
- [Quyền riêng tư](PRIVACY.md)

Raw REA evidence/manual và Apple documentation được giữ cục bộ, không đưa vào release. Mã gốc theo MIT; xem [thông báo bên thứ ba](THIRD_PARTY_NOTICES.md).
