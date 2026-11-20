# Nhật ký sử dụng AI — Đảo Đèn Lồng (Lab 12)

## 1. Các hoạt động có sự hỗ trợ của AI

AI coding assistant được sử dụng để hỗ trợ các công việc sau:

- Rà soát repository theo AGENTS.md, PRD-0, Test Contract v1.0 và kế hoạch các giai đoạn.
- Hỗ trợ xây dựng cấu trúc triển khai và rà soát mã nguồn cho dự án Godot 4.7.2.
- Hỗ trợ phát triển lớp trình bày đồ họa 3D bằng hình khối tạo theo thủ tục, kết nối với SimulationCore dùng chung.
- Hỗ trợ tích hợp cơ chế nhảy, trọng lực, đọc cấu hình từ game contract, tính điểm khi thắng và các thực thể mặc định cho chế độ headless.
- Hỗ trợ rà soát kiểm thử và tài liệu.
- Hỗ trợ phát hiện và sửa lỗi kiểu dữ liệu trong GDScript.
- Rà soát điều kiện tài nguyên trong gameplay và điều chỉnh số lượng đom đóm ban đầu.
- Hỗ trợ kiểm tra tài liệu và danh sách yêu cầu nộp bài.

## 2. Công việc thực hiện và xác minh bởi người phát triển

Người phát triển trực tiếp mở project, kiểm tra và chạy sản phẩm trên môi trường Godot 4.7.2.

Các nội dung đã kiểm tra:

- Di chuyển nhân vật Mây.
- Điều khiển camera và cơ chế nhảy.
- Tương tác trong gameplay.
- Sử dụng phím Q để phát xung sáng.
- Sử dụng phím E để tương tác với đèn lồng.
- Kiểm tra yêu cầu năm đèn lồng, mỗi đèn cần năm đom đóm, tổng cộng 25 đom đóm.
- Kiểm tra luồng chiến thắng và thất bại.
- Chạy bộ kiểm thử mô phỏng ở chế độ headless.

Lệnh kiểm thử:

    godot --headless --path . --script res://tests/test_simulation.gd

Kết quả quan sát được:

    Simulation tests passed.
    EXIT CODE: 0

Kết quả trên xác nhận script kiểm thử chạy hoàn tất với mã thoát bằng 0 trên máy phát triển. Đây chưa phải là kết quả kiểm chứng bằng một bản clone sạch trên máy khác.

## 3. Điều chỉnh quan trọng trong quá trình triển khai — 20/11/2026

Ban đầu, màn chơi đồ họa tạo ra 15 đom đóm, trong khi năm đèn lồng cần tổng cộng 25 đom đóm để thắp sáng.

Số lượng đom đóm ban đầu được điều chỉnh từ 15 lên 25, không thay đổi các giá trị tuning trong game.contract.json.

Bổ sung kiểm thử hồi quy cho tình huống người chơi bị tấn công, làm rơi đom đóm, nhặt lại số đom đóm đã rơi và duy trì trạng thái các đèn lồng đã được thắp sáng.

## 4. Nhật ký xử lý lỗi — 20/11/2026

- Sửa lỗi suy luận kiểu dữ liệu trong scripts/core/simulation.gd bằng cách khai báo tường minh biến chứa kết quả phân tích JSON với kiểu Variant.
- Sửa lỗi suy luận kiểu dữ liệu trong scripts/gameplay/graphical_game.gd bằng cách khai báo tường minh biến target với kiểu Vector3.
- Chạy lại script kiểm thử mô phỏng ở chế độ headless và ghi nhận mã thoát bằng 0.

## 5. Thống kê token và chi phí sử dụng AI

Trong quá trình phát triển, lượng token và chi phí sử dụng AI không được ghi nhận tập trung thành một nhật ký thống kê.

Do đó, số lượng token và chi phí chính xác hiện không có dữ liệu để đối chiếu. Nhật ký không tự đưa ra con số ước tính hồi tố khi chưa có căn cứ.

## 6. Giới hạn và trách nhiệm kiểm tra của người phát triển

Các đề xuất và mã nguồn do AI hỗ trợ tạo ra đều cần được người phát triển rà soát.

Các nội dung về trải nghiệm gameplay, chất lượng hình ảnh, giả định cân bằng trò chơi, tính đúng đắn của triển khai và bằng chứng nghiệm thu vẫn cần được kiểm tra bởi người phát triển.

Phần hình ảnh được mô tả trong quá trình triển khai sử dụng các hình khối 3D tạo theo thủ tục. Không chủ động đưa vào mô hình nhân vật, hình ảnh nghệ thuật hoặc âm thanh bên ngoài trong phần triển khai được ghi nhận tại đây. Nếu bổ sung tài nguyên bên thứ ba, cần cập nhật nguồn và giấy phép tương ứng trong CREDITS.md.

## 7. Bài học rút ra

Quá trình thực hiện dự án cho thấy tầm quan trọng của các nội dung sau:

- Duy trì sự nhất quán giữa mã nguồn và game contract.
- Chạy kiểm thử sau các thay đổi mã nguồn.
- Kiểm tra game thực tế trên đúng phiên bản engine mục tiêu.
- Đồng bộ mã nguồn, README, Test Contract và bằng chứng của từng giai đoạn.
- Bảo đảm lịch sử Git và bằng chứng theo từng phase phản ánh đúng quá trình phát triển thực tế.
