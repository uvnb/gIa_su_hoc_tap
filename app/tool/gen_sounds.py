"""Sinh 3 hiệu ứng âm thanh ngắn (< 1 giây) cho app: pop, ting, tada. Tự tổng hợp → không lo bản quyền.
Chạy: python tool/gen_sounds.py  (ghi vào assets/sounds/)"""
import math, struct, wave, random
from pathlib import Path

SR = 22050
OUT = Path(__file__).resolve().parents[1] / "assets" / "sounds"


def write(name, samples):
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s)) * 30000)) for s in samples))


def tone(freq, dur, vol=0.5, attack=0.005, decay=6.0, harmonics=(1.0, 0.3, 0.1)):
    n = int(SR * dur)
    out = []
    for i in range(n):
        t = i / SR
        env = min(1.0, t / attack) * math.exp(-decay * t)
        s = sum(a * math.sin(2 * math.pi * freq * (k + 1) * t) for k, a in enumerate(harmonics))
        out.append(vol * env * s / sum(harmonics))
    return out


def mix(*tracks):
    n = max(off + len(tr) for off, tr in tracks)
    buf = [0.0] * n
    for off, tr in tracks:
        for i, s in enumerate(tr):
            buf[off + i] += s
    return buf


# pop: tiếng "bóp" ngắn – sóng sin trượt tần số xuống nhanh
pop = []
n = int(SR * 0.09)
phase = 0.0
for i in range(n):
    t = i / SR
    f = 900 - 6000 * t
    phase += 2 * math.pi * max(f, 120) / SR
    pop.append(0.6 * math.exp(-40 * t) * math.sin(phase))
write("pop", pop)

# ting: chuông cao trong trẻo
write("ting", tone(1568, 0.6, vol=0.45, decay=5.5, harmonics=(1.0, 0.5, 0.25, 0.12)))

# tada: hợp âm rải C-E-G-C rồi ngân
notes = [(523.25, 0.0), (659.25, 0.09), (783.99, 0.18), (1046.5, 0.27)]
tracks = [(int(SR * start), tone(f, 0.7 - start * 0.5, vol=0.35, decay=3.2)) for f, start in notes]
write("tada", mix(*tracks))
print("Đã tạo:", ", ".join(p.name for p in sorted(OUT.glob("*.wav"))))


# ================= âm thanh Góc trò chơi =================
def sweep(f0, f1, dur, vol=0.5, decay=6.0, wobble=0.0):
    n = int(SR * dur)
    out, ph = [], 0.0
    for i in range(n):
        t = i / SR
        f = f0 + (f1 - f0) * (t / dur)
        f *= 1 + wobble * math.sin(2 * math.pi * 18 * t)
        ph += 2 * math.pi * f / SR
        out.append(vol * min(1.0, t / 0.005) * math.exp(-decay * t) * math.sin(ph))
    return out


# jump: "boing" vút lên
write("jump", sweep(320, 980, 0.26, vol=0.5, decay=5, wobble=0.04))
# bump: "bịch" trầm, mềm – không chói tai
write("bump", [s * 0.9 for s in sweep(170, 70, 0.28, vol=0.6, decay=9)])
# clear: chuỗi chuông lấp lánh đi lên khi xóa hàng
notes = [(1046.5, 0.0), (1318.5, 0.05), (1568.0, 0.10), (2093.0, 0.15)]
write("clear", mix(*[(int(SR * st), tone(f, 0.32, vol=0.3, decay=7, harmonics=(1.0, 0.4, 0.15))) for f, st in notes]))
# unlock: "đinh-đoong" đi lên khi mở khóa khối bí ẩn
write("unlock", mix((0, tone(783.99, 0.3, vol=0.4, decay=6)), (int(SR * 0.12), tone(1046.5, 0.4, vol=0.4, decay=5))))
# oops: hai nốt đi xuống rất nhẹ – "ơ…", không phải tiếng phạt
write("oops", mix((0, tone(659.25, 0.22, vol=0.25, decay=8, harmonics=(1.0, 0.2))),
                  (int(SR * 0.13), tone(523.25, 0.28, vol=0.25, decay=8, harmonics=(1.0, 0.2)))))
# coin: nhặt sao
write("coin", mix((0, tone(987.77, 0.08, vol=0.35, decay=4)), (int(SR * 0.07), tone(1318.5, 0.3, vol=0.35, decay=6))))
print("Đã tạo âm trò chơi.")
