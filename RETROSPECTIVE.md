# Retrospective — Đảo Đèn Lồng

## What went well

- Hoàn thiện game 3D bằng Godot 4.7.2 với các cơ chế gameplay chính.
- Tách simulation khỏi lớp trình bày đồ họa và duy trì chế độ headless.
- Có Test Contract và test simulation.
- Phát hiện và sửa sai lệch số lượng mote: năm đèn, mỗi đèn cần năm mote, tổng cộng 25 mote.
- Hoàn thành video demo MP4 dài khoảng 122.6 giây.

## What did not go well

- Quá trình tích hợp gặp lỗi kiểu dữ liệu GDScript trên Godot 4.7.2.
- README và một số tài liệu vẫn giữ nhãn Phase 1.
- Evidence Phase 2–4, Git tags và Release cuối chưa được xác minh đầy đủ.
- Một số giả định gameplay vẫn ở trạng thái đề xuất/chưa được phê duyệt.

## Lessons learned

- Chạy kiểm tra compile và test sau mỗi thay đổi; kiểm tra toàn bộ log và mã thoát.
- Đối chiếu tài nguyên ban đầu với điều kiện chiến thắng.
- Duy trì tính nhất quán giữa source code, README, Test Contract, evidence và Git tags.
- Không tạo tag hoặc evidence hồi tố nếu không có commit/bằng chứng tương ứng.

## Follow-up actions

- Rà soát README, AI_JOURNAL.md và ASSUMPTIONS.md.
- Kiểm tra evidence của từng phase.
- Xác minh Git tags, Release v1.0.0 và khả năng clone sạch rồi chạy game/test.
- Bổ sung token và chi phí AI từ dữ liệu sử dụng thực tế, không tự suy đoán.
