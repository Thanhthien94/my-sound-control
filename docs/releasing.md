# Preview release workflow

Tạm thời theo my-fan-control:

1. Cập nhật `VERSION` dạng `0.1.0-preview.1`, changelog và release notes; ghi rõ phần đã đo/chưa kiểm tra.
2. Chạy `./script/test.sh`, `./script/build_and_run.sh --verify`, kiểm tra theo `docs/validation.md`.
3. Commit source và docs. Packaging từ chối working tree chưa sạch.
4. Chạy `./script/package_preview.sh`: release build arm64, ký ad-hoc, kiểm tra signature, DMG có shortcut Applications, ZIP và SHA256SUMS.
5. Kiểm tra signature bản trích từ DMG và checksum. Thử bản tải xuống trước khi ghi nhận đã xác minh cài đặt.
6. Push source lên origin/main; tạo tag đúng commit, GitHub prerelease có DMG/ZIP/checksum. Không đánh dấu stable/latest.

Các lệnh publish sau khi source và assets đã sẵn sàng:

```sh
git push origin main
git tag -a v0.1.0-preview.1 -m 'My Sound Control 0.1.0 Preview 1'
git push origin v0.1.0-preview.1
gh release create v0.1.0-preview.1 \
  --repo Thanhthien94/my-sound-control \
  --verify-tag --prerelease --latest=false \
  --title '0.1.0 Preview 1 — initial application mixer' \
  --notes-file docs/releases/0.1.0-preview.1.md \
  dist/MySoundControl-0.1.0-preview.1-arm64.dmg \
  dist/MySoundControl-0.1.0-preview.1-arm64.zip \
  dist/SHA256SUMS.txt
```

CI trên macos-15-intel chạy test native, cross-build arm64, đóng gói và upload artifact vào workflow run; không tự publish release. Chưa dùng Developer ID, notarization, updater hoặc Homebrew cask. Không tắt Gatekeeper/SIP.

Không đóng gói binary/asset trích từ SoundSource. Raw research evidence/manual giữ cục bộ.
