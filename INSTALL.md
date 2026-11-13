# Cài My Sound Control Preview

Apple Silicon, macOS 15 trở lên. Bản preview ký ad-hoc, chưa notarize bởi Apple.

1. Tải `MySoundControl-<version>-arm64.dmg` từ [GitHub Releases](https://github.com/Thanhthien94/my-sound-control/releases).
2. So sánh SHA-256 với `SHA256SUMS.txt` cùng release: `shasum -a 256 ~/Downloads/MySoundControl-<version>-arm64.dmg`.
3. Mở DMG, kéo MySoundControl.app vào Applications rồi mở app.
4. Nếu macOS báo nhà phát triển chưa được xác minh, mở System Settings → Privacy & Security → Open Anyway cho đúng app vừa tải. Không tắt Gatekeeper hoặc SIP. Nếu báo app bị hỏng, mã độc hoặc lỗi chữ ký, dừng và gửi nguyên thông báo lỗi.
5. App có biểu tượng thanh trượt trên menu bar và không hiện trong Dock. Mở bộ trộn từ menu bar sau khi đóng cửa sổ.
6. Phát nhạc trong một app rồi bật Mixer ở hàng tương ứng. Chỉ lúc này app mới bắt đầu capture và macOS có thể hỏi quyền ghi âm hệ thống. Không cần quyền microphone cho mixer.

Chọn **Trả về âm gốc** để ngừng xử lý; chọn **Thoát** trước khi cập nhật hoặc xóa app. Âm lượng hệ thống do bạn thay đổi vẫn giữ theo thiết lập macOS. Mỗi lần mở app, mixer từng ứng dụng ở trạng thái tắt; thiết lập volume/mute đã lưu chỉ áp dụng khi bạn bật lại.

Giới hạn ban đầu: volume từng app 0–100%, stereo/mono Float32 cùng sample rate; chưa EQ/boost/AU/AirPlay đa thiết bị. Thiết bị duplex/multichannel không tương thích sẽ được báo lỗi. Browser helper có thể hiện thành process riêng.
