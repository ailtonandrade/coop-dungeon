#!/usr/bin/env python3
"""Gera os efeitos sonoros sintetizados do jogo (audio/sfx/*.ogg) e a música/ambiente
provisórios (audio/music/*.ogg). Sons de ferro-velho: golpes, pregos, metal, chip queimando.

São provisórios no mesmo sentido dos modelos: dá para trocar qualquer arquivo por um som de
verdade com o mesmo nome (o banco em audio/sound_bank.gd lista os arquivos de cada evento).

Rodar (precisa de Python 3 com numpy e do ffmpeg no PATH):
    python3 tools/gerar_sons.py
"""
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np

RATE = 44100
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SFX = os.path.join(ROOT, "audio", "sfx")
MUSIC = os.path.join(ROOT, "audio", "music")
rng = np.random.default_rng(7)


# Peças básicas

def t(seconds):
    return np.arange(int(seconds * RATE)) / RATE


def noise(seconds):
    return rng.uniform(-1.0, 1.0, int(seconds * RATE))


def env(n, attack=0.005, decay=None, curve=4.0):
    """Envelope: sobe em `attack` s e cai exponencialmente até o fim (ou em `decay` s)."""
    x = np.arange(n) / RATE
    a = np.clip(x / max(attack, 1e-4), 0.0, 1.0)
    length = decay if decay else n / RATE
    d = np.exp(-curve * np.clip(x - attack, 0.0, None) / max(length, 1e-4))
    return a * d


def onepole_lowpass(x, cutoff):
    """Passa-baixa de um polo; `cutoff` pode ser um número ou um array (varredura)."""
    cutoff = np.broadcast_to(np.asarray(cutoff, dtype=float), x.shape)
    alpha = 1.0 - np.exp(-2.0 * np.pi * cutoff / RATE)
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc += alpha[i] * (x[i] - acc)
        y[i] = acc
    return y


def bandpass(x, low, high):
    return onepole_lowpass(x, high) - onepole_lowpass(onepole_lowpass(x, high), low)


def fft_filter(x, low, high):
    """Filtro de faixa estático pela FFT (rápido para sons longos)."""
    spectrum = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(len(x), 1.0 / RATE)
    mask = (freqs >= low) & (freqs <= high)
    smooth = np.convolve(mask.astype(float), np.ones(64) / 64, mode="same")
    return np.fft.irfft(spectrum * smooth, len(x))


def sweep_sine(f0, f1, seconds, curve=1.0):
    x = t(seconds)
    k = (x / seconds) ** curve
    freq = f0 + (f1 - f0) * k
    return np.sin(2 * np.pi * np.cumsum(freq) / RATE)


def partials(base, ratios, decays, seconds, amps=None):
    x = t(seconds)
    out = np.zeros_like(x)
    amps = amps or [1.0 / (i + 1) for i in range(len(ratios))]
    for ratio, decay, amp in zip(ratios, decays, amps):
        out += amp * np.sin(2 * np.pi * base * ratio * x + rng.uniform(0, 6.28)) * np.exp(-x / decay)
    return out


def square(freq, seconds):
    return np.sign(np.sin(2 * np.pi * freq * t(seconds)))


def saw(freq, seconds, detune=0.0):
    x = t(seconds)
    f = freq * (1 + detune)
    return 2.0 * ((x * f) % 1.0) - 1.0


def crush(x, bits=6, keep=4):
    """Bitcrush: menos bits e segura amostras (som de chip/rádio velho)."""
    held = np.repeat(x[::keep], keep)[: len(x)]
    levels = 2 ** bits
    return np.round(held * levels) / levels


def drive(x, amount=2.0):
    return np.tanh(x * amount) / np.tanh(amount)


def pad(x, seconds):
    return np.concatenate([x, np.zeros(int(seconds * RATE))])


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[: len(p)] += p
    return out


def at(x, seconds, total=None):
    """Desloca `x` para começar em `seconds`."""
    lead = np.zeros(int(seconds * RATE))
    out = np.concatenate([lead, x])
    if total:
        out = pad(out, max(0.0, total - len(out) / RATE))[: int(total * RATE)]
    return out


def echo(x, delay=0.12, feedback=0.35, taps=4):
    out = pad(x, delay * taps)
    step = int(delay * RATE)
    gain = feedback
    for i in range(1, taps + 1):
        out[step * i: step * i + len(x)] += x * gain
        gain *= feedback
    return out


def fade(x, fade_in=0.002, fade_out=0.02):
    n_in = max(1, int(fade_in * RATE))
    n_out = max(1, int(fade_out * RATE))
    x = x.copy()
    x[:n_in] *= np.linspace(0, 1, n_in)
    x[-n_out:] *= np.linspace(1, 0, n_out)
    return x


def save(folder, name, x, peak=0.89, quality=6):
    x = fade(np.nan_to_num(x))
    top = np.max(np.abs(x)) or 1.0
    x = x / top * peak
    data = (x * 32767).astype(np.int16)
    os.makedirs(folder, exist_ok=True)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        path = tmp.name
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data.tobytes())
    target = os.path.join(folder, name + ".ogg")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", path, "-c:a", "libvorbis", "-q:a", str(quality), target], check=True)
    os.remove(path)
    print("  " + os.path.relpath(target, ROOT))


# Efeitos

def whoosh(seconds, low, high, heavy=False):
    n = int(seconds * RATE)
    k = np.linspace(0, 1, n)
    center = low + (high - low) * np.sin(np.pi * k) ** 1.5
    body = bandpass(noise(seconds), center * 0.5, center * 1.4)
    shape = np.sin(np.pi * k) ** (1.2 if heavy else 2.0)
    out = body * shape
    if heavy:
        out += 0.4 * sweep_sine(140, 70, seconds) * shape
    return out


def thump(seconds=0.16, f0=130, f1=50, click=0.6):
    body = sweep_sine(f0, f1, seconds, 0.6) * env(int(seconds * RATE), 0.002, seconds * 0.5)
    snap = onepole_lowpass(noise(0.03), 2500) * env(int(0.03 * RATE), 0.0005, 0.015) * click
    return drive(mix(body, snap), 2.5)


def metal(base, seconds=0.6, bright=1.0):
    ring = partials(base, [1, 2.76, 5.40, 8.93, 13.3], [0.35, 0.22, 0.14, 0.08, 0.05], seconds,
                    [1.0, 0.7 * bright, 0.5 * bright, 0.3 * bright, 0.2 * bright])
    hit = bandpass(noise(0.02), 1500, 9000) * env(int(0.02 * RATE), 0.0003, 0.008)
    return mix(ring * env(len(ring), 0.001, seconds * 0.6), hit * 1.5)


def blip(freq, seconds, kind="square"):
    wave_ = square(freq, seconds) if kind == "square" else np.sin(2 * np.pi * freq * t(seconds))
    return wave_ * env(int(seconds * RATE), 0.002, seconds * 0.7)


def sparkle(seconds=0.7, base=1800, count=9):
    out = np.zeros(int(seconds * RATE))
    for i in range(count):
        start = i * seconds / count * rng.uniform(0.7, 1.0)
        note = blip(base * 2 ** (rng.integers(0, 12) / 12), 0.12, "sine") * (1 - i / count * 0.6)
        out = mix(out, at(note, start))
    return out[: int(seconds * RATE)]


def chord(freqs, seconds, wave_="saw"):
    out = np.zeros(int(seconds * RATE))
    for f in freqs:
        for d in (-0.004, 0.004):
            out += saw(f, seconds, d) if wave_ == "saw" else np.sin(2 * np.pi * f * (1 + d) * t(seconds))
    return out / (len(freqs) * 2)


def make_sfx():
    print("Efeitos:")
    for i in range(3):
        save(SFX, "swing_%d" % (i + 1), whoosh(rng.uniform(0.15, 0.21), 500 + 120 * i, 2600 - 200 * i))
    save(SFX, "swing_heavy", whoosh(0.3, 300, 1700, heavy=True))
    for i in range(3):
        f0 = 150 + 25 * i
        save(SFX, "hit_%d" % (i + 1), mix(thump(0.16, f0, 50), 0.25 * metal(900 + 200 * i, 0.12, 0.5)))
    save(SFX, "hit_heavy", mix(thump(0.26, 110, 38, 1.0), 0.5 * metal(520, 0.4)))
    for i in range(2):
        save(SFX, "metal_%d" % (i + 1), metal(380 + 90 * i, 0.7))
    for i in range(2):
        hiss = bandpass(noise(0.09), 2500, 9000) * env(int(0.09 * RATE), 0.001, 0.04)
        clack = metal(2100 + 300 * i, 0.06, 1.2)
        save(SFX, "nail_shot_%d" % (i + 1), mix(thump(0.08, 160, 80, 1.2) * 0.8, clack, hiss * 0.8))
    save(SFX, "nail_impact", mix(metal(2600, 0.05), thump(0.05, 300, 120, 1.0) * 0.5))
    hiss = bandpass(noise(0.12), 1500, 6000) * env(int(0.12 * RATE), 0.001, 0.06)
    save(SFX, "enemy_shot", mix(thump(0.1, 120, 60, 1.0), metal(1500, 0.08), hiss * 0.7))
    for i in range(2):
        grunt = bandpass(noise(0.18), 380 + 60 * i, 900) * env(int(0.18 * RATE), 0.01, 0.1)
        grunt *= 1 + 0.4 * np.sin(2 * np.pi * 28 * t(0.18))
        save(SFX, "player_hurt_%d" % (i + 1), mix(thump(0.14, 100, 45), grunt * 1.2))
    save(SFX, "dodge", whoosh(0.22, 250, 1200) * 0.9)
    bubbles = np.zeros(int(0.55 * RATE))
    for i in range(8):
        f = rng.uniform(280, 520) * (1 + i * 0.08)
        bubble = sweep_sine(f, f * 1.8, 0.05) * env(int(0.05 * RATE), 0.002, 0.03)
        bubbles = mix(bubbles, at(bubble, i * 0.055 + rng.uniform(0, 0.02)))
    save(SFX, "potion", mix(bubbles, at(sparkle(0.4, 1400, 5) * 0.4, 0.25)))
    save(SFX, "revive", mix(sparkle(0.8, 1200, 8), chord([523, 659, 784], 0.8, "sine") * env(int(0.8 * RATE), 0.2, 0.6) * 0.6))
    save(SFX, "pickup", mix(metal(1500, 0.18, 0.6), at(metal(2250, 0.2, 0.6), 0.06)))
    save(SFX, "loot_drop", mix(thump(0.08, 220, 120, 0.8) * 0.6, metal(1800, 0.15, 0.4) * 0.5))
    save(SFX, "loot_rare", mix(thump(0.08, 220, 120, 0.8) * 0.5, sparkle(0.6, 1500, 7)))
    save(SFX, "loot_unique", mix(thump(0.1, 180, 80, 1.0) * 0.5, sparkle(1.0, 1100, 12),
                                  chord([392, 494, 587, 784], 1.0, "sine") * env(int(1.0 * RATE), 0.05, 0.8) * 0.7))
    creak_t = t(0.45)
    wobble = 140 + 40 * np.sin(2 * np.pi * 7 * creak_t) + 60 * creak_t
    creak = np.sign(np.sin(2 * np.pi * np.cumsum(wobble) / RATE)) * 0.4
    creak = bandpass(creak, 400, 2500) * env(len(creak), 0.05, 0.4, 2.0)
    jingle = sparkle(0.35, 2200, 5) * 0.5
    save(SFX, "chest_open", mix(creak, at(thump(0.12, 160, 70, 1.0), 0.38), at(jingle, 0.42)))
    save(SFX, "container_open", mix(metal(160, 0.9, 0.7) * 0.8, creak * 0.8, at(thump(0.2, 90, 40, 1.0), 0.4)))
    notes = [523, 659, 784, 1047]
    arp = np.zeros(int(1.6 * RATE))
    for i, f in enumerate(notes):
        note = onepole_lowpass(square(f, 0.22) * 0.5 + saw(f * 2, 0.22) * 0.3, 3500) * env(int(0.22 * RATE), 0.004, 0.18)
        arp = mix(arp, at(note, i * 0.09))
    pad_chord = chord([523, 659, 784, 1047], 1.2) * env(int(1.2 * RATE), 0.05, 1.0, 3.0)
    save(SFX, "level_up", echo(mix(arp, at(onepole_lowpass(pad_chord, 2500) * 0.8, 0.36), at(sparkle(0.9, 1600, 10) * 0.7, 0.4)), 0.11, 0.3))
    chip = np.zeros(int(0.4 * RATE))
    for i, f in enumerate([800, 1000, 1200, 1600]):
        chip = mix(chip, at(blip(f, 0.06), i * 0.06))
    save(SFX, "chip_install", crush(mix(chip, at(sparkle(0.25, 2000, 4) * 0.5, 0.2)), 7, 2))
    save(SFX, "ui_move", blip(1800, 0.03, "sine"), peak=0.6)
    save(SFX, "ui_confirm", mix(blip(900, 0.06), at(blip(1350, 0.08), 0.05)) * 0.6, peak=0.7)
    save(SFX, "ui_back", mix(blip(900, 0.06), at(blip(600, 0.08), 0.05)) * 0.6, peak=0.7)
    save(SFX, "ui_error", onepole_lowpass(square(110, 0.18), 1500) * env(int(0.18 * RATE), 0.002, 0.15), peak=0.7)
    save(SFX, "refine_ok", mix(metal(620, 0.9, 1.3), at(sparkle(0.7, 1700, 8), 0.1)))
    fizz = bandpass(noise(0.5), 2000, 8000) * env(int(0.5 * RATE), 0.01, 0.3) * 0.5
    buzz = onepole_lowpass(square(150, 0.4), 1200) * env(int(0.4 * RATE), 0.005, 0.3)
    drop = sweep_sine(300, 80, 0.4) * env(int(0.4 * RATE), 0.005, 0.35) * 0.6
    save(SFX, "refine_fail", mix(buzz, fizz, drop))
    for i in range(2):
        mod = 1 + 0.5 * np.sin(2 * np.pi * (35 + 10 * i) * t(0.5))
        scream = np.sin(2 * np.pi * np.cumsum((900 + 500 * i) * mod * np.linspace(1, 0.7, int(0.5 * RATE))) / RATE)
        scream = crush(scream * env(len(scream), 0.02, 0.4, 2.5), 5, 3)
        stutter = (np.floor(t(0.5) * 24) % 3 != 2).astype(float)
        save(SFX, "corrupted_alert_%d" % (i + 1), scream * stutter * 0.8)
    for i in range(2):
        down = sweep_sine(700 - 120 * i, 60, 0.7, 0.5)
        glitch = crush(down * env(len(down), 0.003, 0.6, 2.0), 4, 6)
        stutter = (np.floor(t(0.7) * 18) % 4 != 3).astype(float)
        save(SFX, "chip_burn_%d" % (i + 1), mix(glitch * stutter, thump(0.18, 120, 40, 1.0) * 0.6, at(bandpass(noise(0.3), 3000, 9000) * env(int(0.3 * RATE), 0.005, 0.2) * 0.4, 0.05)))
    save(SFX, "player_down", mix(sweep_sine(220, 55, 0.7, 0.6) * env(int(0.7 * RATE), 0.01, 0.6), onepole_lowpass(noise(0.7), 600) * env(int(0.7 * RATE), 0.01, 0.4) * 0.5, thump(0.2, 90, 35)))


# Música e ambiente (loops)

def loop_seam(x, seconds=1.0):
    """Faz o fim emendar no começo sem estalo (cruza o último trecho com o começo)."""
    n = int(seconds * RATE)
    head = x[:n].copy()
    out = x[n:].copy()
    k = np.linspace(0, 1, n)
    out[-n:] = out[-n:] * (1 - k) + head * k
    return out


def make_ambience():
    seconds = 42.0
    n = int(seconds * RATE)
    wind = fft_filter(noise(seconds), 80, 700)
    wind *= 0.55 + 0.45 * np.sin(2 * np.pi * t(seconds) / 13.0) ** 2
    hum = (np.sin(2 * np.pi * 60 * t(seconds)) * 0.5 + np.sin(2 * np.pi * 120 * t(seconds)) * 0.3) * 0.08
    out = wind * 0.6 + hum
    # Neon zumbindo de vez em quando e metal batendo longe.
    for start in rng.uniform(2, seconds - 4, 7):
        buzz = onepole_lowpass(square(120, 0.9) * (rng.uniform(0, 1, int(0.9 * RATE)) > 0.3), 900) * env(int(0.9 * RATE), 0.05, 0.8, 2.0) * 0.12
        out = mix(out, at(buzz, start))[:n]
    for start in rng.uniform(2, seconds - 4, 5):
        clank = echo(metal(rng.uniform(250, 420), 0.8) * 0.18, 0.21, 0.4, 3)
        out = mix(out, at(fft_filter(clank, 100, 2500), start))[:n]
    save(MUSIC, "ambiente_ferro_velho", loop_seam(out, 2.0), peak=0.7, quality=4)


def make_menu_music():
    bpm = 92
    beat = 60.0 / bpm
    bars = 8
    seconds = bars * 4 * beat
    n = int(seconds * RATE)
    progression = [[220.0, 261.6, 329.6], [174.6, 220.0, 261.6], [261.6, 329.6, 392.0], [196.0, 246.9, 293.7]]
    out = np.zeros(n + RATE)
    for bar in range(bars):
        notes = progression[bar % 4]
        start = bar * 4 * beat
        pad_ = chord(notes, 4 * beat + 0.4) * env(int((4 * beat + 0.4) * RATE), 0.6, 4 * beat, 1.2)
        sweep = 500 + 900 * (0.5 + 0.5 * np.sin(np.pi * bar / 4))
        out = mix(out, at(onepole_lowpass(pad_, sweep) * 0.55, start))
        bass = onepole_lowpass(saw(notes[0] / 2, 4 * beat), 300) * env(int(4 * beat * RATE), 0.02, 4 * beat, 1.5)
        out = mix(out, at(bass * 0.5, start))
        for step in range(8):
            f = notes[step % 3] * (2 if step % 4 == 3 else 1)
            note = onepole_lowpass(square(f * 2, beat / 2) * 0.3, 2200) * env(int(beat / 2 * RATE), 0.003, beat / 3)
            out = mix(out, at(note * (0.5 if step % 2 else 0.7), start + step * beat / 2))
        for step in range(8):
            hat = bandpass(noise(0.04), 6000, 12000) * env(int(0.04 * RATE), 0.001, 0.02) * (0.25 if step % 2 else 0.12)
            out = mix(out, at(hat, start + step * beat / 2))
    out = echo(out[: n + RATE // 2], beat * 0.75, 0.25, 3)[:n + RATE]
    save(MUSIC, "menu_tema", loop_seam(out[: n + RATE], 1.0), peak=0.75, quality=5)


if __name__ == "__main__":
    if subprocess.run(["ffmpeg", "-version"], capture_output=True).returncode != 0:
        sys.exit("Precisa do ffmpeg no PATH.")
    make_sfx()
    print("Música e ambiente:")
    make_ambience()
    make_menu_music()
