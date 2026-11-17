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
