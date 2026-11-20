# Đảo Đèn Lồng — Các giả định và quyết định chưa được giải quyết (Phase 1)

**Trạng thái:** Các giả định được đề xuất để xem xét; không nội dung nào dưới đây được xem là yêu cầu chính thức của PRD/Test Contract nếu chưa được phê duyệt.

Tài liệu này bổ sung cho:

- `docs/specs/PRD-0.md`
- `docs/specs/test-contract-v1.0.md`
- `docs/plans/phase-1-plan.md`

## 1. Các nội dung đã được quy định rõ — không phải giả định

Các nội dung sau đã được xác định trong tài liệu nguồn:

- Trò chơi thuộc thể loại 3D; Phase 1 diễn ra trong Đêm 1 – Đảo Bến, trên một hòn đảo hình tròn có năm chiếc đèn lồng lớn.
- Mây thu thập đom đóm, nạp ánh sáng vào đèn lồng, tránh né hoặc bị Ink Shades truy đuổi và có thể phát xung ánh sáng để đẩy lùi chúng.
- Thắp sáng tất cả đèn lồng là điều kiện chiến thắng; mất toàn bộ máu là điều kiện thất bại.
- Các nội dung di chuyển, nhảy, camera 3D, HUD, điểm số và chơi lại nằm trong phạm vi Phase 1.
- Mô phỏng sử dụng tần số cố định 60 Hz; chế độ headless không sử dụng cửa sổ đồ họa hoặc GPU.
- Snapshot tại tick 0 được tạo sau khi thiết lập kịch bản và trước khi xử lý đầu vào.
- Khung đầu vào tại tick `k` tạo ra trạng thái `k+1`; các sự kiện trong bước đó sử dụng tick `k+1`.
- Đầu vào được duy trì khi các trường bị lược bỏ; nhảy, tương tác và phát xung là các hành động kích hoạt theo cạnh lên (rising-edge).
- Công thức góc xoay khi di chuyển (movement yaw) và phép chuẩn hóa vector đã được quy định.
- Việc thiết lập kịch bản không phát sinh sự kiện và không cộng điểm.
- Danh sách đom đóm và Ink Shades trong kịch bản thay thế các danh sách ban đầu; trạng thái đèn lồng được cập nhật theo ID.
- Tên snapshot, event, end record cùng các trường và payload bắt buộc đã được quy định.
- JSON hoặc schema của scenario/input không hợp lệ phải kết thúc với mã lỗi 2.
- Cùng seed, scenario và inputs phải tạo ra kết quả giống hệt nhau, bao gồm cả ID được sinh tự động.
- Chế độ headless không được yêu cầu cửa sổ đồ họa hoặc GPU.
- Mảng `motes` trong snapshot được khuyến nghị sử dụng nhưng không bắt buộc.

## 2. Các giả định đề xuất về gameplay và cân bằng trò chơi

| ID | Chủ đề | Quyết định đề xuất | Lý do cần thiết | Cần phê duyệt |
|---|---|---|---|---|
| A-01 | Tốc độ người chơi | `5.0 m/s` | PRD chưa quy định tốc độ di chuyển. | Có |
| A-02 | Sức chứa đom đóm | `5` đom đóm | Cần giới hạn số lượng đom đóm người chơi có thể mang. | Có |
| A-03 | Chi phí thắp đèn | `5` đom đóm mỗi đèn lồng | Cần xác định số lượng đom đóm cần nạp để thắp sáng đèn. | Có |
| A-04 | Bán kính nhặt vật phẩm | `1.5 m` | Contract yêu cầu có giá trị nhưng không quy định cụ thể. | Có |
| A-05 | Bán kính tương tác | `2.5 m` | Contract yêu cầu có giá trị nhưng không quy định cụ thể. | Có |
| A-06 | Số ngọn lửa ban đầu | `3` | PRD quy định người chơi có thể mất máu nhưng không nêu số lượng ban đầu. | Có |
| A-07 | Chi phí phát xung | `1` ngọn lửa | Xung ánh sáng phải tiêu hao năng lượng ánh sáng; đơn vị và giá trị chưa được quy định. | Có |
| A-08 | Bán kính phát xung | `5.0 m` | Cần xác định Ink Shades chịu ảnh hưởng của xung. | Có |
| A-09 | Thời gian làm choáng | `3.0 s` | Cần xác định thời gian đẩy lùi/làm choáng. | Có |
| A-10 | Khoảng cách đẩy lùi | `3.0 m` | Cần xác định khoảng cách Ink Shades bị đẩy lùi. | Có |
| A-11 | Thời gian hồi chiêu của xung | `1.0 s` | Ngăn người chơi kích hoạt xung liên tục; PRD chưa quy định. | Có |
| A-12 | Tốc độ Ink Shade | `3.0 m/s` | PRD quy định Ink Shades truy đuổi người chơi nhưng không nêu tốc độ. | Có |
| A-13 | Bán kính gây sát thương của Shade | `1.0 m` | Contract yêu cầu có giá trị nhưng không quy định cụ thể. | Có |
| A-14 | Thời gian bất tử tạm thời | `1.0 s` | Tránh việc người chơi liên tục nhận sát thương khi tiếp xúc với cùng một đối tượng; chưa được quy định. | Có |
| A-15 | Tỷ lệ rơi đom đóm khi bị đánh | `0.5` | Contract định nghĩa ý nghĩa nhưng chưa quy định giá trị. | Có |
| A-16 | Bán kính vùng an toàn | `4.0 m` | Contract định nghĩa ý nghĩa nhưng chưa quy định giá trị. | Có |
| A-17 | Thời lượng ban đêm | `300 s` | Cần thiết để xác định hành vi bình minh và điều kiện thất bại. | Có |
| A-18 | Hình phạt khi rơi khỏi đảo | `false` | Không áp dụng hình phạt khi rơi trong phiên bản triển khai đầu tiên. | Có |
| A-19 | Điểm số | đom đóm 10, đèn lồng 100, làm choáng 25, mỗi giây còn lại 2, mỗi ngọn lửa còn lại 50 | PRD quy định có hệ thống điểm nhưng chưa đưa ra công thức. | Có |

Các giá trị trên chỉ là những phương án được đề xuất. `game.contract.json` phải luôn đồng bộ với các giá trị thực tế được triển khai.

## 3. Các giả định về hành vi mô phỏng

| ID | Chủ đề | Quyết định đề xuất | Nội dung nguồn chưa quy định |
|---|---|---|---|
| A-20 | Chọn đèn lồng để nạp | Khi có cạnh kích hoạt tương tác, chọn đèn lồng chưa được thắp sáng đủ điều kiện gần nhất; nếu khoảng cách bằng nhau, ưu tiên ID đèn lồng theo thứ tự tăng dần. | Cách chọn đèn khi có nhiều đèn lồng cùng nằm trong phạm vi tương tác. |
| A-21 | Số lượng đom đóm nạp | Nạp `min(carried, lantern_cost - deposited)`. | Có cho phép nạp một phần hay không và số lượng được chuyển mỗi lần. |
| A-22 | Sự kiện nạp đèn | Phát sự kiện `deposit` khi số lượng nạp lớn hơn 0; nếu việc nạp hoàn thành chi phí yêu cầu thì tiếp tục phát `lantern_lit`. | Thứ tự phát sự kiện chính xác chưa được quy định rõ. |
| A-23 | Điểm khi nhặt đom đóm | Cộng `per_mote` tại thời điểm nhặt. | Thời điểm cộng điểm chính xác chưa được quy định ngoài ý nghĩa của trường điểm số. |
| A-24 | Điểm khi thắp đèn | Cộng `per_lantern` một lần khi đèn lồng chuyển trạng thái từ chưa sáng sang đã sáng. | Thời điểm cộng điểm chính xác chưa được quy định. |
| A-25 | Sát thương từ Shade | Mỗi lần bị một Shade tấn công sẽ mất một ngọn lửa. | Số lượng sát thương mỗi lần tiếp xúc chưa được quy định. |
| A-26 | Bất tử tạm thời | Sau khi bị đánh, kích hoạt `invuln_s`; không nhận thêm sát thương trong thời gian này. | Contract cung cấp trường thời lượng nhưng chưa quy định chính xác ngữ nghĩa của va chạm và bộ đếm thời gian. |
| A-27 | Đom đóm bị rơi | Làm rơi `floor(carried * hit_drop_ratio)` đom đóm. | Quy tắc làm tròn và vị trí đom đóm bị rơi chưa được quy định. |
| A-28 | Vị trí đom đóm bị rơi | Tạo lại các đom đóm bị rơi tại tọa độ XZ trên mặt đất của người chơi, sử dụng ID được sinh theo cách xác định. | Vị trí xuất hiện của đom đóm bị rơi chưa được quy định. |
| A-29 | Kích hoạt xung | Xung chỉ hợp lệ khi người chơi đủ năng lượng để trả chi phí và thời gian hồi chiêu bằng 0; chi phí chỉ bị trừ một lần. | Chưa quy định xung có bị tiêu hao năng lượng hoặc phát sự kiện khi không có Shade nào trong phạm vi hay không. |
| A-30 | Xung không có mục tiêu | Một xung hợp lệ nhưng không ảnh hưởng đến Shade nào vẫn phát sự kiện `pulse` với `stunned_ids: []`. | Hành vi sự kiện khi xung không có mục tiêu chưa được quy định. |
| A-31 | Điểm khi làm choáng | Chỉ cộng `per_stun` cho Shade vừa chuyển sang trạng thái bị choáng. | Chưa quy định Shade đã bị choáng có được tính điểm thêm lần nữa hay không. |
| A-32 | Mục tiêu của xung | Chọn các Shade có khoảng cách theo phương ngang `<= pulse_radius`. | Thứ tự tác động và ngữ nghĩa chọn mục tiêu chính xác chưa được quy định. |
| A-33 | Đẩy lùi | Đẩy các Shade bị ảnh hưởng theo phương ngang ra xa Mây một khoảng `pulse_push_m`; sử dụng hướng thay thế cố định nếu hai vị trí trùng nhau. | Hướng đẩy và cách xử lý va chạm chưa được quy định. |
| A-34 | Vùng an toàn | Chỉ các đèn lồng đã được thắp sáng mới tạo vùng an toàn; Shade không được di chuyển vào phạm vi `safe_radius` theo phương ngang của vùng này. | Chưa quy định đèn chưa sáng có tạo vùng an toàn hay không và cách tìm đường di chuyển. |
| A-35 | Trạng thái Shade | Sử dụng `chase` cho trạng thái đang truy đuổi và `stunned` cho trạng thái bị choáng; chỉ bổ sung tên trạng thái khác khi cần thiết. | Contract chỉ bắt buộc trạng thái `stunned`. |
| A-36 | Thứ tự ưu tiên điều kiện kết thúc | Kiểm tra chiến thắng trước, sau đó kiểm tra thất bại do hết ngọn lửa, cuối cùng kiểm tra thất bại do bình minh. | Chưa quy định thứ tự ưu tiên khi nhiều điều kiện kết thúc xảy ra đồng thời. |
| A-37 | Trạng thái kết thúc tại tick 0 | Sau khi thiết lập scenario, trạng thái vẫn là `playing`; điều kiện kết thúc chỉ được đánh giá ở bước mô phỏng đầu tiên đã thực thi. | Chưa quy định scenario đã thỏa mãn điều kiện thắng/thua có kết thúc ngay tại tick 0 hay không. |
| A-38 | Mốc tính thời gian | Nếu scenario cung cấp `time_left_s`, sử dụng giá trị đó làm thời lượng còn lại ban đầu; thời gian sau đó được tính bằng `scenario_time_left - sim_tick/60`. | Contract thể hiện có thể ghi đè thời gian bằng scenario nhưng chưa mô tả rõ công thức tính ở các bước tiếp theo. |
| A-39 | Điểm thưởng thời gian | Khi chiến thắng, sử dụng `floor(time_left_s) * per_second_left`. | Cách biểu diễn giây lẻ và điểm số chưa được quy định. |
| A-40 | Điểm thưởng ngọn lửa còn lại | Khi chiến thắng, cộng thêm `flames_remaining * per_flame_left`. | Chưa quy định rõ phần thưởng chỉ áp dụng khi chiến thắng hay không. Đề xuất chỉ áp dụng khi chiến thắng. |
| A-41 | Thứ tự nhặt đom đóm | Xử lý đom đóm theo ID tăng dần ổn định; dừng khi người chơi đạt sức chứa tối đa. | Thứ tự thu thập khi nhiều đom đóm được nhặt cùng lúc chưa được quy định. |
| A-42 | Nhiều Shade gây sát thương | Xử lý theo ID Shade tăng dần; trạng thái bất tử tạm thời ngăn việc nhận nhiều hơn một lần sát thương trong thời gian hiệu lực. | Hành vi khi nhiều Shade tiếp xúc cùng lúc chưa được quy định. |

## 4. Các giả định về tính xác định và khả năng tái lập kết quả

| ID | Chủ đề | Quyết định đề xuất | Ghi chú |
|---|---|---|---|
| A-43 | PRNG | Sử dụng thuật toán xorshift32 tường minh với trạng thái được giới hạn trong 32 bit. | Test Contract yêu cầu tính xác định nhưng không bắt buộc một thuật toán cụ thể. Cần xác minh hành vi số nguyên và phép toán bit của Godot trên macOS/Linux. |
| A-44 | Seed bằng 0 | Thay trạng thái nội bộ bằng hằng số khác 0 cố định `0x6D2B79F5`. | xorshift32 không thể sử dụng trạng thái bằng 0. Seed bên ngoài từ CLI vẫn được giữ nguyên. |
| A-45 | Luồng RNG | Sử dụng một luồng trạng thái thuộc quyền quản lý của state; thứ tự gọi phải xác định; không sử dụng RNG của engine hoặc RNG toàn cục. | Ngăn nền tảng và thứ tự dựng hình ảnh làm thay đổi kết quả. |
| A-46 | ID đèn lồng | `L1`–`L5`. | ID được suy ra từ các ví dụ overlay scenario. |
| A-47 | ID đom đóm | `M1`, `M2`, … theo thứ tự tạo. | Contract không quy định ID đom đóm vì danh sách mote trong snapshot là tùy chọn. |
| A-48 | ID Shade | `S1`, `S2`, …; giữ nguyên ID được cung cấp rõ trong scenario; cấp ID còn thiếu theo cách xác định. | Ví dụ trong contract sử dụng S1/S3 và yêu cầu ID sinh tự động phải ổn định, nhưng chưa quy định chính xác quy tắc cấp ID. |
| A-49 | Thứ tự thực thể | Sắp xếp các mảng đầu ra và quá trình xử lý trong cùng giai đoạn theo ID ổn định. | Ngăn thứ tự duyệt dictionary làm thay đổi kết quả. |
| A-50 | Lịch sinh thực thể ngẫu nhiên | Sử dụng các khoảng tick cố định và vị trí ứng viên/phương pháp lấy mẫu có tính xác định. | PRD quy định các thực thể xuất hiện nhưng chưa đưa ra tần suất, giới hạn số lượng hoặc phân phối vị trí. |
| A-51 | Giới hạn vị trí sinh ngẫu nhiên | Vị trí ứng viên phải nằm trong đảo và nằm ngoài các vùng không hợp lệ/vùng an toàn khi áp dụng. | Bán kính đảo và hình học khu vực sinh thực thể chưa được quy định. |

## 5. Các giả định về đầu vào và kiểm tra tính hợp lệ

| ID | Chủ đề | Quyết định đề xuất | Ghi chú |
|---|---|---|---|
| A-52 | Khóa JSON không xác định | Từ chối các khóa không được định nghĩa trong tài liệu scenario/input. | Contract chưa quy định nên bỏ qua hay từ chối các trường không xác định. |
| A-53 | Giá trị carried trong scenario | Yêu cầu `0 <= carried <= carry_capacity`. | Contract quy định trường dữ liệu là số nguyên nhưng chưa nêu rõ việc kiểm tra giới hạn sức chứa. |
| A-54 | Giá trị deposited của đèn lồng | Yêu cầu số nguyên `0 <= deposited <= lantern_cost`. | Ngăn trạng thái đèn lồng không hợp lệ; contract chưa quy định giới hạn này. |
| A-55 | Tính nhất quán giữa trạng thái lit và deposited | Giữ nguyên các giá trị được cung cấp rõ ràng; không tự suy ra `lit` từ `deposited` nếu chưa có quy tắc được phê duyệt và ghi nhận. | Contract cho phép `lit:true` nhưng chưa định nghĩa các ràng buộc nhất quán. |
| A-56 | ID trong scenario | Từ chối ID Shade được khai báo trùng lặp và ID đèn lồng không tồn tại. | Tránh các tham chiếu không rõ ràng. |
| A-57 | Frame nằm ngoài thời lượng chạy | Chấp nhận frame có tick >= số bước được yêu cầu nhưng bỏ qua frame đó trong lần chạy hiện tại. | Contract chưa quy định frame ngoài phạm vi chạy phải bị từ chối hay được bỏ qua. |
| A-58 | `--ticks 0` | Chấp nhận số tick bằng 0; xuất snapshot tại tick 0 và end record với số bước bằng 0. | Contract quy định N bước nhưng chưa nói rõ trường hợp N bằng 0. |
| A-59 | Chu kỳ snapshot | Yêu cầu `snapshot_every` là số nguyên dương. | Giá trị mặc định 10 đã được quy định; hành vi khi bằng 0 chưa được nêu. |
| A-60 | Mã lỗi CLI | Sử dụng mã thoát 1 cho lỗi CLI/config/runtime; mã thoát 2 dành riêng cho JSON/schema scenario/input không hợp lệ. | Chỉ mã lỗi 2 đối với scenario/input được quy định rõ. |
| A-61 | Chuyển đổi thời lượng | Yêu cầu thời lượng có thể chuyển đổi thành số tick nguyên; nếu không thì từ chối cấu hình. | Tránh việc tự ý làm tròn khi chưa có quy tắc được quy định. |

## 6. Các giả định về thế giới mặc định và phần trình bày

Các nội dung sau cần được xác định trước khi triển khai gameplay và phải được ghi nhận bằng giá trị thực tế:

1. Bán kính đảo hình tròn và ranh giới rơi khỏi đảo.
2. Tọa độ mặc định của năm đèn lồng.
3. Số lượng và vị trí mặc định của đom đóm.
4. Số lượng và vị trí mặc định của Shade.
5. Khoảng thời gian sinh đom đóm/Shade ngẫu nhiên, số lượng tối đa đang hoạt động và khu vực sinh.
6. Vận tốc/độ cao khi nhảy, trọng lực và hành vi điều khiển khi ở trên không.
7. Góc xoay camera, độ nhạy, mức thu phóng và hành vi xử lý va chạm.
8. Hướng di chuyển của người chơi và việc góc xoay camera có được điều khiển bằng chuột hay tay cầm hay không.
9. Cường độ/phạm vi ánh sáng của đèn lồng và cách hòn đảo sáng dần khi từng đèn được thắp lên.
10. Bố cục HUD và các chỉ số hiển thị cụ thể (tối thiểu gồm số ngọn lửa, lượng ánh sáng đang mang, tiến độ thắp đèn, bộ đếm thời gian và điểm số).
11. Thiết kế màn hình chiến thắng/thất bại và phím khởi động lại.
12. Có đưa âm thanh vào Phase 1 hay không; âm thanh không được ảnh hưởng đến mô phỏng.

## 7. Danh sách kiểm tra phê duyệt

Trước khi triển khai, cần phê duyệt hoặc điều chỉnh các nội dung sau:

- [ ] Các giá trị cân bằng được đề xuất từ A-01 đến A-19.
- [ ] Ngữ nghĩa nạp đèn và tính điểm tại A-20 đến A-24 và A-39/A-40.
- [ ] Ngữ nghĩa sát thương và làm rơi vật phẩm tại A-25 đến A-28.
- [ ] Ngữ nghĩa phát xung tại A-29 đến A-35.
- [ ] Ngữ nghĩa kết thúc trò chơi và thời gian tại A-36 đến A-40.
- [ ] Chính sách PRNG xác định và quy tắc cấp ID tại A-43 đến A-51.
- [ ] Chính sách kiểm tra tính hợp lệ tại A-52 đến A-61.
- [ ] Hình học thế giới mặc định, lịch sinh thực thể, camera và cơ chế nhảy tại Mục 6.

## 8. Các điểm chưa được làm rõ có mức độ ưu tiên cao nhất

1. **Ngữ nghĩa tính điểm:** thời điểm cộng từng loại điểm và việc điểm thưởng thời gian/ngọn lửa có chỉ được áp dụng khi chiến thắng hay không.
2. **Điểm thưởng thời gian lẻ:** `per_second_left` sử dụng floor, round, điểm số thập phân hay quy tắc khác.
3. **Ngữ nghĩa sát thương:** số ngọn lửa bị trừ mỗi lần trúng đòn và quy tắc làm tròn/vị trí chính xác của đom đóm bị rơi.
4. **Ngữ nghĩa phát xung:** xung không có mục tiêu có tiêu hao năng lượng/phát sự kiện hay không; cách tương tác giữa đẩy lùi và làm choáng.
5. **Ngữ nghĩa nạp đèn:** có cho phép nạp một phần hay không, cách chọn đèn khi nhiều đèn nằm trong phạm vi và thứ tự phát sự kiện.
6. **Thứ tự ưu tiên điều kiện kết thúc:** trường hợp tất cả đèn đã sáng, người chơi hết ngọn lửa và bình minh xảy ra đồng thời.
7. **Scenario kết thúc tại tick 0:** scenario đã ở trạng thái thắng/thua có kết thúc trước khi thực hiện bước mô phỏng đầu tiên hay không.
8. **Sinh thực thể ngẫu nhiên:** số lượng, tần suất, giới hạn, phân phối và việc các cờ random trong scenario chỉ ảnh hưởng đến các lần sinh sau đó hay không.
9. **Hình học thế giới:** bán kính đảo, ranh giới rơi khỏi đảo và vị trí mặc định của các thực thể.
10. **Mức độ nghiêm ngặt khi kiểm tra dữ liệu:** khóa không xác định, chấp nhận số nguyên/số thực và giá trị scenario nằm ngoài phạm vi.
11. **Quy ước ranh giới bộ đếm thời gian:** tick chính xác mà trạng thái choáng, bất tử tạm thời và hồi chiêu hết hiệu lực.
12. **Tuần tự hóa tọa độ:** contract yêu cầu làm tròn đến 3 chữ số thập phân nhưng chưa quy định cách biểu diễn trong JSON (ví dụ `1` hay `1.000`).

Không được âm thầm tự lựa chọn các hành vi chưa được quy định. Mọi lựa chọn đã được phê duyệt cần được ghi nhận tại đây và giữ cho `game.contract.json` đồng bộ với hành vi thực tế.
