# PRD-0 — Đảo Đèn Lồng (Lantern Island)
## Phase 1

## 1. Chúng tôi muốn gì

Chúng tôi muốn một **game 3D** tên là **Đảo Đèn Lồng**.

Người chơi điều khiển **Mây**, người giữ đèn nhỏ tuổi của một hòn đảo giữa biển mây. Đêm nay sương đen đã nuốt hết ánh sáng của đảo. Mây phải chạy khắp đảo **thu thập những đốm sáng (đom đóm)** rồi mang về **thắp lại các Đèn Lồng Lớn**.

Trong bóng tối có **Bóng Mực**, những sinh vật bằng mực đen sống trong sương. Chúng đuổi theo Mây; bị chúng chạm vào thì **mất máu**. Mây có thể **tỏa sáng** để xua chúng đi, nhưng việc đó tốn ánh sáng. Bóng Mực **sợ những chiếc đèn**.

Thắp hết đèn thì **thắng**. Mất hết máu thì **thua**. Có **điểm số**.

## 2. Phạm vi Phase 1

- Một màn chơi: **Đêm 1 – Đảo Bến**, một hòn đảo tròn có **5 Đèn Lồng Lớn**.
- Nhân vật đi lại, nhảy, camera 3D.
- Đom đóm xuất hiện rải rác trên đảo, nhặt được.
- Nạp ánh sáng vào đèn để thắp đèn.
- Bóng Mực xuất hiện và đuổi người chơi.
- Tỏa sáng để xua Bóng Mực.
- Thắng, thua, điểm số, giao diện hiển thị thông tin cần thiết (HUD).
- Có thể chơi lại sau khi thắng hoặc thua.

## 3. Cảm giác & phong cách

- Không khí **đêm, ấm áp, cổ tích**.
- Đảo **sáng dần lên** khi thắp đèn.
- Ánh sáng **vàng cam ấm** là thứ tốt.
- Màu **tím đen** là nguy hiểm.
- Phong cách đồ họa **đơn giản nhưng đẹp**. Không cần đồ họa chân thực.
- Mây đội **nón lá có treo một chiếc đèn lồng nhỏ**.
- Không bạo lực, không máu me.

## 4. Không bắt buộc công nghệ

Bạn được tự chọn engine, ngôn ngữ và framework. Game phải chạy được trên laptop (macOS hoặc Linux; nếu bạn dùng Windows thì phải có cách chạy trên macOS/Linux cho giảng viên, ví dụ Docker hoặc bản web).

## 5. Bàn giao Phase 1

Nộp bằng tag git `phase-1` trên repo public.

1. Game chơi được Đêm 1 từ đầu tới thắng/thua.
2. `README.md`: cách cài đặt và chạy (tối đa 3 lệnh), điều khiển, cách tính điểm của bạn.
3. `game.contract.json` và chế độ headless theo **Test Contract v1.0** dưới đây.
4. Bằng chứng game chạy đúng yêu cầu, cùng ghi chép ngắn (giả định, nhật ký dùng AI). Định dạng tự chọn.
5. Harness AI bạn đã dùng (`AGENTS.md` hoặc tương đương, skills, hooks…).

## 6. Lưu ý

- **Game tốt là game đúng yêu cầu của khách hàng**, không phải game phức tạp hay đẹp nhất.
- **Cân nhắc kỹ quota token.** Đốt nhiều token không làm bài tốt hơn.
- **Không có bằng chứng thì chưa xong.** "Agent bảo chạy rồi" không phải bằng chứng.
- Chỗ PRD-0 còn mơ hồ: tự giả định hợp lý và ghi lại.
