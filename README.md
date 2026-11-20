# Đảo Đèn Lồng

[🎬 Xem video demo](docs/demo/demo.mp4)

Game 3D Godot 4.7.2: Đêm 1 – Đảo Bến. Mây thu thập đom đóm, nạp năm Đèn Lồng Lớn và né Bóng Mực trên hòn đảo giữa biển mây.

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
- Di chuyển chuột: xoay camera; con lăn: zoom.
- `Esc`: thả chuột; click trái để bắt chuột lại.
- `R`: chơi lại sau khi thắng/thua.

## Luật và điểm

- Nhặt đom đóm: +10 điểm.
- Thắp một đèn: +100 điểm.
- Làm choáng Bóng Mực mới: +25 điểm.
- Khi thắng: cộng `floor(time_left_s) × 2` và `flames_remaining × 50`.
- Người chơi có 3 flame; va chạm Bóng Mực làm mất 1 flame và rơi 50% số đom đóm đang mang (làm tròn xuống).
- Xung sáng tốn 1 đom đóm, bán kính 5 m, đẩy Bóng Mực 3 m và làm choáng 3 giây.
- Đèn đã sáng tạo vùng an toàn bán kính 4 m.

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

Đây là prototype Phase 1 dùng hình khối 3D dựng procedural, không sử dụng model/âm thanh bên ngoài. Cần chạy trên Godot 4.7.2 để xác nhận import, rendering và tương tác đồ họa trên máy đích.
