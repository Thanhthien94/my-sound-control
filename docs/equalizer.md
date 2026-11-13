# Equalizer

## Sử dụng

Bấm **EQ** ở dòng ứng dụng để mở bảng 10 băng. Có thể chuẩn bị cấu hình khi Mixer tắt; để nghe thay đổi cần bật cả **Mixer** và **Bật EQ**. Bypass giữ các mức chỉnh nhưng bỏ qua cả EQ và preamp. **Đặt lại** đưa các băng/preamp về 0 dB và bật tự bù headroom, giữ trạng thái bật/bypass.

Các tâm băng là 31,25; 62,5; 125; 250; 500 Hz; 1; 2; 4; 8; 16 kHz. Mỗi băng ±12 dB, bước UI 0,5 dB. Năm preset định hướng âm sắc: Phẳng, Âm trầm, Giọng nói, Trong sáng, Êm dịu. Đây là preset riêng của dự án, không phải profile hiệu chỉnh tai nghe. Chọn preset chỉ đổi các băng; preamp, auto-headroom và bật/bypass giữ nguyên.

Cấu hình được lưu theo định danh bundle khi có; nguồn chỉ có PID giữ trong phiên vì macOS tái sử dụng PID. Browser helper vẫn có thể là nguồn riêng. Chưa có thư viện preset đặt tên, nhập/xuất profile hoặc parametric EQ.

## Headroom và clipping

Preamp giảm thêm từ 0 tới −24 dB. Tự bù headroom mặc định bật: quét đáp tuyến kết hợp của 10 filter ở 1025 điểm logarithmic và các tâm băng, giảm gain theo đỉnh ước lượng rồi chừa thêm 1 dB khi có nâng dải. Vì vậy nâng bass có thể làm tổng mức nghe nhỏ đi.

Đây là ước lượng đáp tuyến, không bảo đảm mọi transient hoặc inter-sample peak. Khi EQ bật hoặc đang crossfade với EQ, đầu ra sau volume được chặn ở ±1 và đếm frame bị cắt đỉnh. UI báo đã cắt đỉnh trong phiên; hạ preamp/mức nâng để giảm méo. Không gọi cơ chế này là limiter, compressor hoặc true-peak protection. EQ bypass hoàn toàn không thay đổi đặc tính headroom của luồng gốc.

## Engine và luồng cấu hình

`tap → preamp/headroom → 10 peaking biquads → volume/mute ramp → sample clamp nếu EQ bật → output/meter`.

RBJ peaking filters, Q=1,4, direct form II transposed với hệ số và state double. Hai kênh có state riêng. Băng từ 0,49 × sample rate trở lên được bỏ qua. Pipeline mới tạo lại hệ số theo sample rate nguồn; giới hạn output/source cùng sample rate của mixer vẫn áp dụng.

Control thread duy nhất tính hệ số và auto-headroom. Ba slot cấu hình trao quyền sở hữu qua atomic exchange acquire/release: producer sở hữu back, callback sở hữu front, middle chuyển giao cấu hình mới nhất. Callback chỉ nhận tại đầu block khi không crossfade. Hai bank có state độc lập được crossfade tuyến tính trong 20 ms; cập nhật nhanh được gộp về cấu hình cuối trong khi hoàn tất transition. Callback không cấp phát, khóa, log, tính sin/cos hoặc cập nhật UI. Atomics phải lock-free khi tạo processor.

## Tương thích dữ liệu và rollback

`mixer.preferences.v1` giữ các trường cũ và thêm `equalizer`. Bản không có trường EQ đọc thành EQ tắt, flat, auto-headroom bật. Giá trị/band count được chuẩn hóa; không tự bật capture lúc launch. Bản preview.3 bỏ qua trường EQ lạ khi đọc; nếu bản cũ ghi lại preferences, cấu hình EQ có thể bị mất. Sao lưu preferences trước khi rollback nếu cần giữ EQ.

## Kiểm chứng và giới hạn

Xem `validation.md` và release notes. Đo đáp tuyến bằng sine trong DSP khác với nghe A/B trên nhiều nguồn/thiết bị. Chưa đánh giá chất lượng nghe, latency, true peak, CPU trên máy yếu hoặc mở rộng AU/headphone correction.
