#!/usr/bin/env python3
"""Gera os efeitos sonoros sintetizados do jogo (audio/sfx/*.ogg) e a música/ambiente
provisórios (audio/music/ambiente*.ogg; o piano é do tools/gerar_piano.py). Sons de ferro-velho: golpes, pregos, metal, chip queimando.

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


def nail_shot(seed):
    """Pregador pneumático, abafado e realista: ESTALO seco na frente (transiente curtíssimo, de
    banda larga), pistão batendo (grave curto), rajada de ar comprimido e escape; depois eco leve
    de rua (duas batidas nas paredes, abafadas) e uma cauda curta de ambiente. Nada de anel."""
    r = np.random.default_rng(100 + seed)
    total = 0.75
    crack_n = r.uniform(-1, 1, int(0.006 * RATE))
    crack = (crack_n - onepole_lowpass(crack_n, 900)) * env(len(crack_n), 0.0001, 0.0018) * 2.6
    snap_n = r.uniform(-1, 1, int(0.02 * RATE))
    snap = bandpass(snap_n, 700, 4200) * env(len(snap_n), 0.0002, 0.006) * 1.4
    knock = sweep_sine(r.uniform(230, 280), r.uniform(80, 95), 0.09, 0.5) * env(int(0.09 * RATE), 0.0004, 0.03) * 1.3
    burst_n = r.uniform(-1, 1, int(0.07 * RATE))
    burst = bandpass(burst_n, 600, 4000) * env(len(burst_n), 0.0006, 0.022) * 0.8
    exhaust_n = r.uniform(-1, 1, int(0.2 * RATE))
    exhaust = onepole_lowpass(exhaust_n, np.linspace(3800, 1200, len(exhaust_n))) - onepole_lowpass(exhaust_n, 500)
    exhaust *= env(len(exhaust_n), 0.008, 0.1, 3.0) * 0.18
    shot = mix(drive(mix(crack, snap, knock), 2.2), burst, at(exhaust, 0.02))
    # Abafado: corta o chiado de cima.
    shot = onepole_lowpass(onepole_lowpass(shot, 6500), 8000)
    # Eco leve: duas reflexões (parede perto e longe), mais escuras e baixas.
    slap1 = onepole_lowpass(shot, 1800) * 0.28
    slap2 = onepole_lowpass(shot, 1100) * 0.14
    # Cauda curta de ambiente (ruído decaindo, bem grave).
    tail_n = r.uniform(-1, 1, int(0.5 * RATE))
    tail = onepole_lowpass(tail_n, 900) * env(len(tail_n), 0.01, 0.22, 3.5) * 0.09
    out = mix(shot, at(slap1, 0.07), at(slap2, 0.16), at(tail, 0.02))
    return pad(out, max(0.0, total - len(out) / RATE))[: int(total * RATE)]


def nail_impact_wall(seed):
    """Prego batendo em parede/chão: "tok" seco e abafado com um pouquinho de poeira e cacos.
    Sem ressonância (nada de plim)."""
    r = np.random.default_rng(200 + seed)
    knock = sweep_sine(r.uniform(380, 460), r.uniform(150, 190), 0.04, 0.6) * env(int(0.04 * RATE), 0.0003, 0.012)
    tick_n = r.uniform(-1, 1, int(0.008 * RATE))
    tick = bandpass(tick_n, 1200, 4500) * env(len(tick_n), 0.0001, 0.002) * 0.9
    dust_n = r.uniform(-1, 1, int(0.12 * RATE))
    dust = bandpass(dust_n, 400, 2200) * env(len(dust_n), 0.002, 0.04, 3.0) * 0.35
    grains = np.zeros(int(0.2 * RATE))
    for _ in range(4):
        g_n = r.uniform(-1, 1, int(0.006 * RATE))
        g = bandpass(g_n, 1500, 5000) * env(len(g_n), 0.0002, 0.002) * r.uniform(0.08, 0.18)
        start = int(r.uniform(0.03, 0.15) * RATE)
        grains[start:start + len(g)] += g[: len(grains) - start]
    out = mix(drive(mix(knock, tick), 1.6), dust, grains)
    return onepole_lowpass(out, 5000)


def nail_impact_body(seed):
    """Prego entrando no corpo (sucata, couro, carne): baque grave e curto, abafado."""
    r = np.random.default_rng(300 + seed)
    thud = sweep_sine(r.uniform(170, 200), r.uniform(70, 85), 0.07, 0.6) * env(int(0.07 * RATE), 0.0005, 0.025)
    slap_n = r.uniform(-1, 1, int(0.04 * RATE))
    slap = onepole_lowpass(slap_n, 1100) * env(len(slap_n), 0.0003, 0.012) * 0.7
    out = drive(mix(thud * 1.2, slap), 2.0)
    return onepole_lowpass(out, 3500)


def swing_heavy():
    """Golpe final do combo: o mesmo "swaaash" de ar, mais longo e encorpado, SEM baque grave
    no fim (antes tinha uma senoide descendo que soava como "pumm")."""
    n_sec = 0.36
    n = int(n_sec * RATE)
    k = np.linspace(0, 1, n)
    center = 260 + (1500 - 260) * np.sin(np.pi * k) ** 1.5
    body = bandpass(noise(n_sec), center * 0.5, center * 1.5)
    shape = np.sin(np.pi * k) ** 1.4
    return body * shape


def make_nail_shots():
    for i in range(3):
        save(SFX, "nail_shot_%d" % (i + 1), nail_shot(i))
    for i in range(3):
        save(SFX, "nail_impact_%d" % (i + 1), nail_impact_wall(i))
        save(SFX, "nail_body_%d" % (i + 1), nail_impact_body(i))


def make_sfx():
    print("Efeitos:")
    for i in range(3):
        save(SFX, "swing_%d" % (i + 1), whoosh(rng.uniform(0.15, 0.21), 500 + 120 * i, 2600 - 200 * i))
    save(SFX, "swing_heavy", swing_heavy())
    for i in range(3):
        f0 = 150 + 25 * i
        save(SFX, "hit_%d" % (i + 1), mix(thump(0.16, f0, 50), 0.25 * metal(900 + 200 * i, 0.12, 0.5)))
    save(SFX, "hit_heavy", mix(thump(0.26, 110, 38, 1.0), 0.5 * metal(520, 0.4)))
    for i in range(2):
        save(SFX, "metal_%d" % (i + 1), metal(380 + 90 * i, 0.7))
    make_nail_shots()
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
    save(SFX, "loot_drop", mix(thump(0.08, 220, 120, 0.8) * 0.6, metal(1800, 0.15, 0.4) * 0.5))
    save(SFX, "loot_rare", mix(thump(0.08, 220, 120, 0.8) * 0.5, sparkle(0.6, 1500, 7)))
    save(SFX, "loot_unique", mix(thump(0.1, 180, 80, 1.0) * 0.5, sparkle(1.0, 1100, 12),
                                  chord([392, 494, 587, 784], 1.0, "sine") * env(int(1.0 * RATE), 0.05, 0.8) * 0.7))
    creak_t = t(0.45)
    wobble = 140 + 40 * np.sin(2 * np.pi * 7 * creak_t) + 60 * creak_t
    creak = np.sign(np.sin(2 * np.pi * np.cumsum(wobble) / RATE)) * 0.4
    creak = bandpass(creak, 400, 2500) * env(len(creak), 0.05, 0.4, 2.0)
    jingle = sparkle(0.35, 2200, 5) * 0.5
    notes = [523, 659, 784, 1047]
    arp = np.zeros(int(1.6 * RATE))
    for i, f in enumerate(notes):
        note = onepole_lowpass(square(f, 0.22) * 0.5 + saw(f * 2, 0.22) * 0.3, 3500) * env(int(0.22 * RATE), 0.004, 0.18)
        arp = mix(arp, at(note, i * 0.09))
    pad_chord = chord([523, 659, 784, 1047], 1.2) * env(int(1.2 * RATE), 0.05, 1.0, 3.0)
    make_level_up()
    chip = np.zeros(int(0.4 * RATE))
    for i, f in enumerate([800, 1000, 1200, 1600]):
        chip = mix(chip, at(blip(f, 0.06), i * 0.06))
    save(SFX, "chip_install", crush(mix(chip, at(sparkle(0.25, 2000, 4) * 0.5, 0.2)), 7, 2))
    make_ui()
    make_loot_sounds()
    make_steps()
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


# Interface: tudo macio, curto e grave (nada de "plim"): toque de tecla de borracha e
# "toc" abafado, como um botão bom de apertar.

def soft_tick(body=420.0, seconds=0.035, air=0.25, seed=0):
    """Tique macio: um corpinho grave que cai rápido + um sopro de ataque, filtrado."""
    rng_ = np.random.default_rng(seed)
    n = int(seconds * RATE)
    tone = sweep_sine(body * 1.15, body * 0.85, seconds, 0.5) * env(n, 0.0015, seconds * 0.35)
    snap = onepole_lowpass(rng_.uniform(-1, 1, n), 3200) * env(n, 0.0004, 0.006) * air
    return onepole_lowpass(mix(tone, snap), 2600)


def soft_thock(f0, f1, seconds=0.09, seed=0):
    """"Toc" de confirmar: cai de f0 para f1, abafado, com um leve corpo de madeira."""
    rng_ = np.random.default_rng(seed)
    n = int(seconds * RATE)
    tone = sweep_sine(f0, f1, seconds, 0.7) * env(n, 0.002, seconds * 0.4)
    wood = bandpass(rng_.uniform(-1, 1, n), 500, 1800) * env(n, 0.0005, 0.012) * 0.35
    return onepole_lowpass(mix(tone, wood), 2200)


def key_click(seed, pitch=1.0):
    """Tecla de teclado bom: estalinho curto de plástico + corpinho grave, cada um diferente."""
    rng_ = np.random.default_rng(seed)
    seconds = 0.04
    n = int(seconds * RATE)
    click = bandpass(rng_.uniform(-1, 1, n), 1800 * pitch, 5200 * pitch) * env(n, 0.0002, 0.004)
    body = np.sin(2 * np.pi * (190 + rng_.uniform(-25, 25)) * pitch * t(seconds)) * env(n, 0.001, 0.012) * 0.6
    return onepole_lowpass(mix(click * 0.7, body), 4500)


# Saque: tudo abafado e "de verdade" (pano, madeira, metal grosso), nada de tom afinado.

def rustle(seconds, seed, low=250, high=1800, grains=7):
    """Remexer em coisas: uns sopros de ruído filtrado em sequência irregular (pano, papel)."""
    rng_ = np.random.default_rng(seed)
    n = int(seconds * RATE)
    out = np.zeros(n)
    for _ in range(grains):
        start = rng_.uniform(0, seconds * 0.8)
        length = rng_.uniform(0.04, 0.11)
        g = int(length * RATE)
        grain = bandpass(rng_.uniform(-1, 1, g), low * rng_.uniform(0.8, 1.2), high * rng_.uniform(0.8, 1.2))
        grain *= np.sin(np.pi * np.linspace(0, 1, g)) ** 2 * rng_.uniform(0.4, 1.0)
        a = int(start * RATE)
        b = min(a + g, n)
        out[a:b] += grain[:b - a]
    return out


def latch(seed, f=900):
    """Trinco abafado: estalo curto de metal, sem anel longo."""
    rng_ = np.random.default_rng(seed)
    n = int(0.05 * RATE)
    click = bandpass(rng_.uniform(-1, 1, n), f * 0.6, f * 2.5) * env(n, 0.0003, 0.008)
    knock = sweep_sine(f * 0.3, f * 0.2, 0.05) * env(n, 0.0005, 0.012) * 0.5
    return onepole_lowpass(mix(click, knock), 2800)


def make_loot_sounds():
    # Caixa/baú: trinco, a tampa batendo surda e a mão remexendo dentro.
    chest = mix(latch(31, 800) * 0.8, at(thump(0.14, 110, 55, 0.4), 0.09),
                at(rustle(0.5, 32) * 0.55, 0.2))
    save(SFX, "chest_open", onepole_lowpass(onepole_lowpass(chest, 2000), 2400), peak=0.75)
    # Contêiner de metal: trinco mais grosso, a porta pesada e o remexer.
    box = mix(latch(33, 600), at(thump(0.22, 85, 40, 0.5), 0.1), at(metal(140, 0.35, 0.3) * 0.25, 0.1),
              at(rustle(0.55, 34, 200, 1500) * 0.5, 0.28))
    save(SFX, "container_open", onepole_lowpass(onepole_lowpass(box, 1800), 2000), peak=0.75)
    # Pegar item: guardar na mochila (um "tuc" surdo + o pano da bolsa).
    take = mix(thump(0.09, 150, 85, 0.3), at(rustle(0.16, 35, 300, 2000, 3) * 0.6, 0.01))
    save(SFX, "pickup", onepole_lowpass(onepole_lowpass(take, 1800), 2200), peak=0.7)
    # Moedas (parafusos): um punhado tilintando abafado dentro da mão, curtinho.
    rng_ = np.random.default_rng(36)
    coins = np.zeros(int(0.22 * RATE))
    for i in range(4):
        f = rng_.uniform(2400, 3400)
        ping = partials(f, [1, 1.47, 2.1], [0.03, 0.02, 0.015], 0.08, [1.0, 0.5, 0.3])
        coins = mix(coins, at(ping * rng_.uniform(0.4, 0.9), 0.015 + i * rng_.uniform(0.025, 0.045), 0.22))
    coins = mix(onepole_lowpass(coins, 3000) * 0.6, thump(0.07, 160, 90, 0.2) * 0.5)
    save(SFX, "coin_pickup", coins, peak=0.6)


# Passos no chão de terra batida e cascalho: baque surdo do calcanhar + o cascalho rangendo.

def footstep(seed, weight=1.0):
    rng_ = np.random.default_rng(seed)
    heel = thump(0.07, 95 * rng_.uniform(0.9, 1.1), 55, 0.2) * 0.8 * weight
    grit = bandpass(rng_.uniform(-1, 1, int(0.12 * RATE)), 700, 4000)
    grit *= env(len(grit), 0.004, 0.035) * rng_.uniform(0.35, 0.5)
    # Grãos soltos de cascalho logo depois.
    crunch = rustle(0.12, seed + 100, 1200, 5000, 4) * 0.25
    return onepole_lowpass(mix(heel, at(grit, 0.005), at(crunch, 0.02)), 3800)


def make_steps():
    for i in range(5):
        save(SFX, "step_%d" % (i + 1), footstep(50 + i), peak=0.6)
    # Pulo: o impulso dos dois pés (um passo mais firme e o raspar do cascalho), sem "boing".
    push = mix(footstep(60, 1.3), at(footstep(61, 0.9) * 0.7, 0.035), at(rustle(0.15, 62, 400, 2500, 3) * 0.3, 0.02))
    save(SFX, "jump_push", push, peak=0.65)
    # Pouso: os dois pés juntos, mais pesado.
    land = mix(thump(0.12, 85, 45, 0.3), at(footstep(63, 1.2), 0.01), at(footstep(64, 1.0) * 0.8, 0.03))
    save(SFX, "land_feet", onepole_lowpass(land, 3000), peak=0.7)


def make_level_up():
    """Subir de nível: um "pupp" grave e abafado (bolha surda), com um sopro curto embaixo."""
    seconds = 0.32
    n = int(seconds * RATE)
    body = sweep_sine(210, 95, seconds, 0.45) * env(n, 0.004, seconds * 0.35)
    breath = onepole_lowpass(noise(0.12), 900) * env(int(0.12 * RATE), 0.01, 0.05) * 0.25
    tail = sweep_sine(140, 120, 0.25, 1.0) * env(int(0.25 * RATE), 0.02, 0.12) * 0.25
    pupp = mix(body, at(breath, 0.0), at(tail, 0.05))
    save(SFX, "level_up", onepole_lowpass(onepole_lowpass(pupp, 1200), 1500), peak=0.6)


def make_quest_sounds():
    """Missão: tudo abafado. Aceitar = carimbo surdo no papel; pronta = dois toques graves;
    entregar = carimbo + o pano da bolsa (recebeu algo)."""
    stamp = mix(thump(0.12, 120, 60, 0.25), at(rustle(0.12, 70, 300, 1600, 3) * 0.35, 0.01))
    save(SFX, "quest_accept", onepole_lowpass(onepole_lowpass(stamp, 1600), 2000), peak=0.6)
    knock = mix(soft_thock(220, 150, seed=71), at(soft_thock(260, 180, seed=72) * 0.8, 0.14))
    save(SFX, "quest_ready", onepole_lowpass(knock, 1800), peak=0.55)
    done = mix(thump(0.14, 110, 55, 0.25), at(rustle(0.25, 73, 300, 1800, 4) * 0.4, 0.05),
               at(soft_thock(200, 140, seed=74) * 0.6, 0.18))
    save(SFX, "quest_done", onepole_lowpass(onepole_lowpass(done, 1700), 2000), peak=0.6)


def make_ui():
    save(SFX, "ui_move", soft_tick(440, seed=1), peak=0.5)
    save(SFX, "ui_confirm", soft_thock(330, 210, seed=2), peak=0.6)
    save(SFX, "ui_back", soft_thock(250, 160, seed=3), peak=0.6)
    save(SFX, "ui_error", onepole_lowpass(square(110, 0.16), 900) * env(int(0.16 * RATE), 0.002, 0.08), peak=0.5)
    for i in range(4):
        save(SFX, "ui_type_%d" % (i + 1), key_click(10 + i), peak=0.5)
    # Voz de NPC digitando: mais grave e abafada que a tecla, para não cansar numa fala longa.
    for i in range(3):
        save(SFX, "npc_type_%d" % (i + 1), onepole_lowpass(key_click(20 + i, 0.7), 2400), peak=0.5)


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
    # (Tirados: o zumbido de neon picotado e o metal batendo longe soavam aleatórios demais.)
    save(MUSIC, "ambiente_ferro_velho", loop_seam(out, 2.0), peak=0.7, quality=4)


def make_rain():
    """Chuva em loop: chiado largo e macio (chuva longe) + gotas batendo perto (chão, lata, toldo)."""
    seconds = 24.0
    n = int(seconds * RATE)
    rng_ = np.random.default_rng(77)
    bed = fft_filter(rng_.uniform(-1, 1, n), 300, 6000)
    bed = onepole_lowpass(bed, 4500)
    # Sobe e desce devagar (rajadas).
    bed *= 0.8 + 0.2 * np.sin(2 * np.pi * t(seconds) / 7.0) ** 2
    drops = np.zeros(n)
    for _ in range(1400):
        start = int(rng_.uniform(0, seconds - 0.05) * RATE)
        length = int(rng_.uniform(0.006, 0.02) * RATE)
        grain = bandpass(rng_.uniform(-1, 1, length), rng_.uniform(900, 2500), rng_.uniform(3500, 8000))
        grain *= env(length, 0.0003, length / RATE * 0.4) * rng_.uniform(0.2, 1.0)
        drops[start:start + length] += grain
    # Gotas mais pesadas de vez em quando (lata, toldo).
    for _ in range(90):
        start = int(rng_.uniform(0, seconds - 0.2) * RATE)
        tone = metal(rng_.uniform(500, 1400), 0.12, 0.3) * rng_.uniform(0.05, 0.15)
        drops[start:start + len(tone)] += tone[: n - start]
    out = bed * 0.55 + onepole_lowpass(drops, 6000) * 0.5
    save(MUSIC, "chuva", loop_seam(out, 2.0), peak=0.7, quality=4)


if __name__ == "__main__":
    if subprocess.run(["ffmpeg", "-version"], capture_output=True).returncode != 0:
        sys.exit("Precisa do ffmpeg no PATH.")
    if sys.argv[1:] == ["ui"]:
        make_ui()
        sys.exit(0)
    if sys.argv[1:] == ["nivel"]:
        make_level_up()
        sys.exit(0)
    if sys.argv[1:] == ["missao"]:
        make_quest_sounds()
        sys.exit(0)
    if sys.argv[1:] == ["chuva"]:
        make_rain()
        sys.exit(0)
    if sys.argv[1:] == ["passos"]:
        make_steps()
        sys.exit(0)
    if sys.argv[1:] == ["tiro"]:
        make_nail_shots()
        sys.exit(0)
    if sys.argv[1:] == ["golpe"]:
        save(SFX, "swing_heavy", swing_heavy())
        sys.exit(0)
    if sys.argv[1:] == ["saque"]:
        make_loot_sounds()
        sys.exit(0)
    make_sfx()
    print("Música e ambiente:")
    make_ambience()
