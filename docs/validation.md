# Validation — 0.1.0-preview.1

Ngày: 13/11/2026. Máy phát triển Apple Silicon, macOS 27.2.1; Swift 6.4.2 CLT, SDK 26.5. Mức tương thích tối thiểu trong bundle là macOS 15, chưa thử máy macOS 15 thực tế.

## Tự động

- `./script/test.sh`: 8 Swift Testing tests qua. Bao phủ gain/peak stereo, downmix mono, ramp về mute, độc lập giữa hai processor, NaN/Infinity, malformed input, planar stereo và frame-count mismatch.
- `clang -std=c11 -Wall -Wextra -Werror -fsyntax-only ... AudioDSP.c`: qua.
- `bash -n script/*.sh`: qua.
- Debug build và `.app` launch qua `./script/build_and_run.sh --verify`: qua, quan sát UI bằng CUA.
- CLT linker cảnh báo về các đường dẫn framework Developer không tồn tại và arclite; không có lỗi compiler/linker.

## Runtime quan sát trực tiếp

Nguồn thử: `afplay` phát file Float PCM từ tone stereo nhỏ, không phải âm thanh cá nhân. Chỉ bật mixer cho process thử; Chrome đang phát được liệt kê nhưng không bị capture/điều khiển.

1. App mở cửa sổ mixer, đọc đúng thiết bị output/input và danh sách process. Không có Dock icon là chủ ý.
2. Headphone Lenovo và MacBook Pro Speakers đều có output 44.100 Hz. Microphone Lenovo có 16.000 Hz; microphone tích hợp có 48.000 Hz. Không thay đổi default device hoặc sample rate phần cứng trong phép thử.
3. Global stereo-mix tap ban đầu bị từ chối do khác sample rate. Đã sửa dùng device-scoped tap theo thiết bị đang phát của process; phiên khởi động ở 44.100 Hz.
4. CUA xác nhận Mixer bật trên process thử, meter đầu ra −50 dBFS ở gain 100%.
5. Giảm gain xuống 50%: meter −56 dBFS, phù hợp giảm khoảng 6 dB.
6. Mute: meter −∞ dBFS. Unmute phục hồi mức tín hiệu.
7. Đổi riêng đầu ra của process thử sang MacBook Pro Speakers: phiên khởi động lại, giữ gain 50% và meter −56 dBFS. Đây là kiểm chứng pipeline và meter, chưa phải phép ghi âm vật lý ở loa.
8. Bấm Trả về âm gốc: Mixer tắt, volume riêng disable, trạng thái về âm gốc. HAL inventory sau stop không có aggregate của My Sound Control. Không ghi nhận lỗi cleanup trong unified log.

Không có prompt TCC mới xuất hiện trong lần thử thành công. Chưa kiểm tra permission denial, cấp quyền trên máy sạch hoặc permission sau thay chữ ký ad-hoc.

## Cần thử thêm

- Nghe A/B, đo latency và phát hiện tiếng kép bằng loopback/đo ngoài. Chưa tuyên bố chất lượng âm thanh hoặc độ trễ đạt chuẩn.
- Hai app thực phát đồng thời, browser nhiều helper và app tự chọn output riêng.
- Sleep/wake, unplug/reconnect Bluetooth, restart coreaudiod, engine crash giữa phiên và cleanup lỗi. Có logic dừng phiên; chưa fault-inject các trường hợp này.
- Thiết bị USB duplex, multichannel, sample-rate khác nhau; không có resampler độc lập trong preview này.
- UI hardware volume/mute trên thiết bị có master property ghi được. Headphone hiện tại không cung cấp master volume qua property đã dùng; UI disable đúng chức năng đó.
- Cài từ DMG tải qua trình duyệt, Gatekeeper trên máy khác, Intel và macOS 15.

## Acceptance cho lần tiếp theo

Đo round-trip latency, thêm lifecycle test với fake HAL, xác minh quyền từ máy sạch và hai app độc lập. Chỉ sau đó mở rộng EQ/boost, hotkeys, plugin AU và nhóm đầu ra/AirPlay.
