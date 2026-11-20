# Đảo Đèn Lồng

[🎬 Xem video demo](docs/demo/demo.mp4)

Game 3D Godot 4.7.2: Mây thu thập đom đóm, thắp Đèn Lồng và né Bóng Mực qua ba đêm: Đảo Bến, Đảo Cau và Đảo Chuông.

Yêu cầu hệ thống: Godot 4.7.2, macOS hoặc Linux; GPU hỗ trợ OpenGL Compatibility. Benchmark mở cửa sổ 1280×720 và cố gắng tắt VSync.

## Chạy game

Cài Godot 4.7.2, sau đó tại thư mục repository:

```bash
godot --headless --path . --editor --quit
godot --path .
```

## Điều khiển

- `W A S D`: di chuyển theo hướng camera.
- `Space`: nhảy.
- `E`: nạp đom đóm vào đèn gần nhất.
- `Q`: phát xung sáng, tiêu hao 1 đom đóm.
- `Shift`: lướt 0.2 giây theo hướng đang đi.
- `P`: tạm dừng/tiếp tục mô phỏng.
- `C`: bật/tắt bảng màu dễ phân biệt (được lưu cục bộ).
- Di chuyển chuột: xoay camera; con lăn: zoom.
- `Esc`: thả chuột; click trái để bắt chuột lại.
- `R`: chơi lại sau khi thắng/thua.

## Luật và điểm

- Đèn mới cần 10 đom đóm, có 100 dầu và hao 1 dầu/giây; thắp lại sau khi cạn cần 5 đom đóm. Châm dầu dùng đom đóm để thêm 10 dầu mỗi chiếc.
- Mỗi đom đóm nạp vào đèn: +5; thắp lần đầu: +100; thắp lại: +40; Tỏa Sáng trúng Bóng Mực: +5 (hoặc tổng +15 nếu nó đang hút dầu).
- Chỉ xét kết quả ở bình minh: cần tối thiểu 60% đèn đang sáng. Mỗi đèn sáng thưởng `50 + floor(fuel)` và mỗi Ngọn Lửa còn lại +50.
- Người chơi có 3 flame; va chạm Bóng Mực làm mất 1 flame và rơi 50% số đom đóm đang mang (làm tròn xuống).
- Đèn chỉ tạo vùng an toàn bán kính 6 m khi dầu còn ít nhất 30; Bóng Mực có thể hút dầu ở đèn yếu.
- Đêm 2–3 có Gió Lạc cướp đom đóm; Bùa Gió tăng tốc trong 10 giây; Đêm 3 có gió mạnh theo chu kỳ.

Các tuning values được giữ trong `game.contract.json`; simulation đọc tuning từ file này. Các lựa chọn gameplay chưa được PRD/Test Contract quy định (ví dụ vị trí mặc định, tốc độ nhảy, trọng lực, số lượng đom đóm/Bóng Mực ban đầu) là quyết định triển khai, không phải yêu cầu nguyên văn của khách hàng.

## Headless contract

```bash
godot --headless --path . --script res://scripts/headless/main.gd -- --seed 123 --night 1 --ticks 600 --out /tmp/lantern.jsonl
```

Có thể thêm `--scenario file.json`, `--inputs file.json` và `--snapshot-every 10`. JSONL chỉ xuất `snapshot`, `event`, `end`. Lỗi schema scenario/inputs trả mã 2.

## Kiểm thử

```bash
godot --headless --path . --script res://tests/test_simulation.gd
./tests/run_contract_checks.sh
```

## Benchmark, soak và leaderboard

```bash
godot --path . --script res://scripts/benchmark/main.gd -- --seed 42 --duration 30 --out bench.json
godot --headless --path . --script res://scripts/soak/main.gd -- --seed 7 --nights 10 --out soak.json
godot --headless --path . --script res://scripts/runtime/run.gd -- --export-leaderboard out.json
```

Benchmark dùng cảnh chuẩn 200 Bóng Mực, 100 đom đóm, ba đèn sáng và camera orbit. `C` bật chế độ màu dễ phân biệt; `L` mở bảng xếp hạng. Sau khi thua hoặc thắng Đêm 3, nhập tên hợp lệ rồi nhấn Enter để lưu top 10 cục bộ.

## Phạm vi

Đây là bản chuẩn bị phát hành v1.0.0. Chi tiết contract và acceptance criteria nằm ở [Ticket-04](docs/specs/TICKET-04.md) và [Phase 4 plan](docs/plans/phase-4-plan.md).
