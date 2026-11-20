# Đảo Đèn Lồng

[🎬 Xem video demo](docs/demo/demo.mp4)

Game 3D Godot 4.7.2: Mây thu thập đom đóm, thắp Đèn Lồng và né Bóng Mực qua ba đêm: Đảo Bến, Đảo Cau và Đảo Chuông.

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
- Di chuyển chuột: xoay camera; con lăn: zoom.
- `Esc`: thả chuột; click trái để bắt chuột lại.
- `R`: chơi lại sau khi thắng/thua.

## Luật và điểm

- Nạp một đom đóm: +10 điểm; thắp một đèn: +100 điểm.
- Tỏa Sáng trúng Bóng Mực: +5 điểm, tốn 3 đom đóm, bán kính 5 m và làm choáng 2 giây.
- Khi thắng: cộng `floor(time_left_s) × 2` và `flames_remaining × 50`.
- Người chơi có 3 flame; va chạm Bóng Mực làm mất 1 flame và rơi 50% số đom đóm đang mang (làm tròn xuống).
- Đèn đã sáng tạo vùng an toàn bán kính 6 m.
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

## Phạm vi

Đây là prototype Phase 2 với lõi mô phỏng quyết định dùng chung cho đồ họa và headless. Chi tiết contract và acceptance criteria nằm ở [Ticket-02](docs/specs/TICKET-02.md) và [Phase 2 plan](docs/plans/phase-2-plan.md).
