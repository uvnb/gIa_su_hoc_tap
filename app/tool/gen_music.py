"""Sinh nhạc nền vòng lặp cho Góc trò chơi – giai điệu tự sáng tác, tự tổng hợp → không lo bản quyền.
  blocks.wav : "Vui xếp khối"  – 120 nhịp/phút, Đô trưởng, tung tăng
  runner.wav : "Cú chạy băng băng" – 140 nhịp/phút, La thứ, sôi động
Chạy: python tool/gen_music.py  (ghi vào assets/music/). Vòng lặp liền mạch (đuôi nốt quấn về đầu bài).
"""
import math
import random
import struct
import wave
from pathlib import Path

SR = 22050
OUT = Path(__file__).resolve().parents[1] / "assets" / "music"
NOTE_INDEX = {"C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "F": 5, "F#": 6, "Gb": 6,
              "G": 7, "G#": 8, "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11}


def freq(name: str) -> float:
    pitch, octave = name[:-1], int(name[-1])
    midi = 12 * (octave + 1) + NOTE_INDEX[pitch]
    return 440.0 * 2 ** ((midi - 69) / 12)


class Song:
    def __init__(self, bpm: float, bars: int):
        self.eighth = 60.0 / bpm / 2
        self.n = int(round(SR * self.eighth * 8 * bars))
        self.buf = [0.0] * self.n

    def add(self, start_s: float, samples):
        off = int(start_s * SR)
        n = self.n
        buf = self.buf
        for i, s in enumerate(samples):
            buf[(off + i) % n] += s  # quấn đuôi về đầu → lặp liền mạch

    def write(self, name: str):
        peak = max(abs(s) for s in self.buf) or 1.0
        g = 0.85 / peak
        OUT.mkdir(parents=True, exist_ok=True)
        with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s * g)) * 32000)) for s in self.buf))
        print(f"✔ {name}.wav  {self.n / SR:.1f} giây")


def env(i, n, attack=0.01, release=0.04, decay=2.5, sustain=0.65):
    t = i / SR
    a = min(1.0, t / attack)
    d = sustain + (1 - sustain) * math.exp(-decay * t)
    r = min(1.0, (n - i) / (release * SR))
    return a * d * r


def lead(f, dur, vol=0.3):
    """Pulse 25% mềm (cộng hài) + rung nhẹ – nghe như máy chơi game cũ nhưng dịu tai."""
    n = int(dur * SR)
    out = []
    ph = 0.0
    amps = [math.sin(math.pi * k * 0.25) / k for k in range(1, 8)]
    norm = sum(abs(a) for a in amps)
    for i in range(n):
        t = i / SR
        vib = 1 + (0.006 * math.sin(2 * math.pi * 5.5 * t) if t > 0.12 else 0)
        ph += 2 * math.pi * f * vib / SR
        s = sum(a * math.sin(k * ph) for k, a in enumerate(amps, start=1)) / norm
        out.append(vol * env(i, n, decay=3.0, sustain=0.55) * (0.75 * s + 0.25 * math.sin(ph)))
    return out


def pluck(f, dur, vol=0.12):
    n = int(dur * SR)
    return [vol * min(1.0, i / 60) * math.exp(-7 * i / SR) *
            (math.sin(2 * math.pi * f * i / SR) + 0.35 * math.sin(4 * math.pi * f * i / SR)) for i in range(n)]


def bass(f, dur, vol=0.28):
    n = int(dur * SR)
    out = []
    for i in range(n):
        ph = 2 * math.pi * f * i / SR
        tri = math.sin(ph) - math.sin(3 * ph) / 9 + math.sin(5 * ph) / 25
        out.append(vol * env(i, n, attack=0.006, release=0.03, decay=4, sustain=0.6) * tri)
    return out


def kick(vol=0.55):
    n = int(0.16 * SR)
    out, ph = [], 0.0
    for i in range(n):
        t = i / SR
        ph += 2 * math.pi * (55 + 90 * math.exp(-30 * t)) / SR
        out.append(vol * math.exp(-18 * t) * math.sin(ph))
    return out


_rnd = random.Random(7)


def snare(vol=0.2):
    n = int(0.14 * SR)
    out, prev = [], 0.0
    for i in range(n):
        t = i / SR
        x = _rnd.uniform(-1, 1)
        hp = x - prev  # lọc cao thô cho tiếng "tách"
        prev = x
        out.append(vol * math.exp(-22 * t) * (0.7 * hp + 0.3 * math.sin(2 * math.pi * 190 * t)))
    return out


def hat(vol=0.05, length=0.035):
    n = int(length * SR)
    out, prev = [], 0.0
    for i in range(n):
        x = _rnd.uniform(-1, 1)
        out.append(vol * math.exp(-90 * i / SR) * (x - prev))
        prev = x
    return out


CHORDS = {
    "C": ["C", "E", "G"], "G": ["G", "B", "D"], "Am": ["A", "C", "E"], "F": ["F", "A", "C"],
    "Dm": ["D", "F", "A"], "E": ["E", "G#", "B"],
}


def place_melody(song: Song, melody):
    t = 0.0
    for note, eighths in melody:
        d = eighths * song.eighth
        if note != "R":
            song.add(t, lead(freq(note), d * 0.92))
        t += d


def blocks():
    song = Song(bpm=120, bars=8)
    e = song.eighth
    prog = ["C", "G", "Am", "F", "C", "G", "F", "G"]
    melody = [
        ("E5", 1), ("G5", 1), ("C6", 2), ("G5", 1), ("E5", 1), ("G5", 2),
        ("D5", 1), ("G5", 1), ("B5", 2), ("A5", 1), ("G5", 1), ("D5", 2),
        ("C5", 1), ("E5", 1), ("A5", 2), ("G5", 1), ("E5", 1), ("C5", 1), ("E5", 1),
        ("F5", 2), ("A5", 1), ("G5", 1), ("F5", 1), ("E5", 1), ("D5", 2),
        ("E5", 1), ("G5", 1), ("C6", 1), ("E6", 1), ("D6", 2), ("C6", 2),
        ("B5", 1), ("A5", 1), ("G5", 1), ("A5", 1), ("B5", 2), ("D6", 2),
        ("C6", 1), ("A5", 1), ("F5", 1), ("A5", 1), ("G5", 1), ("F5", 1), ("E5", 1), ("F5", 1),
        ("G5", 2), ("R", 1), ("D5", 1), ("E5", 1), ("F5", 1), ("G5", 2),
    ]
    place_melody(song, melody)
    for b, ch in enumerate(prog):
        bar = b * 8 * e
        r, third, fifth = CHORDS[ch]
        # bass: nốt gốc – quãng 5 – gốc cao – quãng 5 (mỗi phách)
        for k, nm in enumerate([r + "2", fifth + "2", r + "3", fifth + "2"]):
            song.add(bar + k * 2 * e, bass(freq(nm), 2 * e * 0.85))
        # rải hợp âm nhẹ
        for k, nm in enumerate([r + "4", third + "4", fifth + "4", r + "5", fifth + "4", third + "4", r + "4", third + "4"]):
            song.add(bar + k * e, pluck(freq(nm), e * 1.6))
        # trống: kick 1 & 3, vỗ tay 2 & 4, hi-hat mỗi móc đơn
        for beat in range(4):
            song.add(bar + beat * 2 * e, kick() if beat % 2 == 0 else snare())
        for k in range(8):
            song.add(bar + k * e, hat(0.06 if k % 2 else 0.035))
    song.write("blocks")


def runner():
    song = Song(bpm=140, bars=8)
    e = song.eighth
    prog = ["Am", "F", "C", "G", "Am", "F", "G", "E"]
    melody = [
        ("A4", 1), ("C5", 1), ("E5", 1), ("A5", 1), ("G5", 1), ("E5", 1), ("C5", 1), ("E5", 1),
        ("F5", 2), ("E5", 1), ("C5", 1), ("A4", 2), ("C5", 2),
        ("G5", 1), ("E5", 1), ("C5", 1), ("E5", 1), ("G5", 1), ("C6", 1), ("B5", 1), ("G5", 1),
        ("D5", 1), ("G5", 1), ("B5", 2), ("A5", 1), ("G5", 1), ("D5", 2),
        ("A5", 1), ("R", 1), ("A5", 1), ("B5", 1), ("C6", 2), ("A5", 2),
        ("A5", 1), ("R", 1), ("A5", 1), ("G5", 1), ("F5", 2), ("C5", 2),
        ("B4", 1), ("D5", 1), ("G5", 1), ("D5", 1), ("B5", 1), ("G5", 1), ("D6", 2),
        ("E5", 1), ("G#5", 1), ("B5", 1), ("E6", 1), ("D6", 1), ("B5", 1), ("G#5", 2),
    ]
    place_melody(song, melody)
    for b, ch in enumerate(prog):
        bar = b * 8 * e
        r, third, fifth = CHORDS[ch]
        # bass chạy móc đơn: gốc – gốc cao xen kẽ → cảm giác đang chạy
        for k in range(8):
            nm = (r + "2") if k % 2 == 0 else (r + "3")
            song.add(bar + k * e, bass(freq(nm), e * 0.8, vol=0.26))
        for k, nm in enumerate([r + "4", fifth + "4", r + "5", third + "5"] * 2):
            song.add(bar + k * e, pluck(freq(nm), e * 1.4, vol=0.1))
        # trống: kick 1, "và" của 2, 3 · snare 2 & 4 · hi-hat móc kép
        for pos in (0, 3, 4):
            song.add(bar + pos * e, kick(0.5))
        for pos in (2, 6):
            song.add(bar + pos * e, snare(0.22))
        for k in range(16):
            song.add(bar + k * e / 2, hat(0.05 if k % 2 else 0.03, 0.025))
    song.write("runner")


if __name__ == "__main__":
    blocks()
    runner()
