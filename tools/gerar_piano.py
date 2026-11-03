#!/usr/bin/env python3
"""Gera a trilha de piano do Corrumpted (audio/music/*.ogg): piano grave, lento e com muito
espaço, para o clima de reflexão e saudade da lore (ver docs/LORE.md e docs/SOM.md).

O piano é sintetizado por modelo físico simplificado, nada de "bip":
- cada nota soma os harmônicos de uma corda de verdade, levemente desafinados para cima
  (inarmonicidade), 3 cordas por nota um pouco desafinadas entre si (o coro que esquenta o som),
  e cada harmônico morre num tempo diferente (agudos somem antes; decaimento em duas fases);
- martelo de feltro: ataque macio, posição do martelo tirando alguns harmônicos, e uma batida
  abafada de madeira no começo; "piano de feltro" (abafado), o timbre das trilhas sensoriais;
- sala grande: reverb estéreo longo (resposta de impulso sintética), pedal segurando as notas.

Uso: python3 tools/gerar_piano.py   (precisa de numpy e do ffmpeg no PATH)
"""
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np

RATE = 44100
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MUSIC = os.path.join(ROOT, "audio", "music")
rng = np.random.default_rng(7)

NOTE_INDEX = {"C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "F": 5, "F#": 6, "Gb": 6,
              "G": 7, "G#": 8, "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11}


def freq(name):
    """'D3' -> Hz (A4 = 440)."""
    pitch, octave = name[:-1], int(name[-1])
    midi = 12 * (octave + 1) + NOTE_INDEX[pitch]
    return 440.0 * 2 ** ((midi - 69) / 12.0), midi


def piano_note(name, velocity=0.6, hold=4.0):
    """Uma nota de piano de feltro. `hold`: quanto tempo o pedal/tecla segura (depois abafa)."""
    f0, midi = freq(name)
    low = np.clip((72 - midi) / 48.0, 0.0, 1.0)  # 1 = grave, 0 = agudo
    length = hold + 2.5
    n = int(length * RATE)
    t = np.arange(n) / RATE
    out = np.zeros(n)
    inharm = 0.00008 + 0.0004 * (1 - low) ** 2
    partials = int(min(24, 9000 / f0))
    hammer = 1.0 / 7.3
    brightness = 0.35 + 0.5 * velocity  # feltro: pouco brilho; tocar mais forte abre um pouco
    for k in range(1, partials + 1):
        fk = k * f0 * np.sqrt(1 + inharm * k * k)
        if fk > 16000:
            break
        amp = (1.0 / k ** 1.15) * abs(np.sin(np.pi * k * hammer)) * np.exp(-(k - 1) * (0.55 - 0.3 * brightness))
        # Agudos morrem antes; notas graves sustentam bem mais.
        tau_fast = (0.35 + 1.4 * low) / (1 + 0.25 * k)
        tau_slow = (2.5 + 9.0 * low) / (1 + 0.12 * k)
        decay = 0.55 * np.exp(-t / tau_fast) + 0.45 * np.exp(-t / tau_slow)
        partial = np.zeros(n)
        for detune in (-0.9, 0.0, 0.8):  # 3 cordas, em cents
            fd = fk * 2 ** (detune / 1200.0)
            partial += np.sin(2 * np.pi * fd * t + rng.uniform(0, 2 * np.pi))
        out += amp * decay * partial / 3.0
    # Ataque macio do feltro (2 a 8 ms) e abafador quando solta.
    attack = np.minimum(1.0, t / (0.002 + 0.006 * (1 - velocity)))
    release = np.where(t < hold, 1.0, np.exp(-(t - hold) / 0.35))
    out *= attack * release
    # Batida do martelo: ruído grave e curto (madeira e feltro).
    thump_n = int(0.05 * RATE)
    thump = rng.normal(0, 1, thump_n) * np.exp(-np.arange(thump_n) / (0.008 * RATE))
    thump = lowpass(thump, 700 + 900 * velocity)
    out[:thump_n] += thump * 0.03 * velocity
    return out * velocity / max(np.max(np.abs(out)), 1e-9) * (0.8 + 0.4 * low)


def lowpass(x, cutoff):
    alpha = 1.0 - np.exp(-2.0 * np.pi * cutoff / RATE)
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc += alpha * (x[i] - acc)
        y[i] = acc
    return y


def fft_lowpass(x, cutoff):
    spectrum = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(len(x), 1.0 / RATE)
    spectrum *= 1.0 / np.sqrt(1.0 + (freqs / cutoff) ** 4)
    return np.fft.irfft(spectrum, len(x))


def reverb(stereo, seconds=3.6, wet=0.3):
    """Sala grande: resposta de impulso de ruído que decai, mais escura no fim, um canal por lado."""
    n = int(seconds * RATE)
    tt = np.arange(n) / RATE
    out = []
    for side in range(2):
        ir = rng.normal(0, 1, n) * np.exp(-tt * 6.9 / seconds)
        ir = fft_lowpass(ir, 3500) * 0.6 + fft_lowpass(ir, 900) * 0.4
        ir[: int(0.02 * RATE)] *= np.linspace(0, 1, int(0.02 * RATE))  # pré-delay suave
        ir /= np.sqrt(np.sum(ir ** 2))
        size = 1 << int(np.ceil(np.log2(len(stereo[side]) + n)))
        wet_side = np.fft.irfft(np.fft.rfft(stereo[side], size) * np.fft.rfft(ir, size), size)[: len(stereo[side])]
        out.append(stereo[side] * (1 - wet) + wet_side * wet * 1.6)
    return np.array(out)


def drone(note, seconds, level=0.03):
    """Tapete grave quase inaudível (cordas/órgão distante) por baixo do piano."""
    f0, _ = freq(note)
    t = np.arange(int(seconds * RATE)) / RATE
    tone = sum(np.sin(2 * np.pi * f0 * k * t * (1 + 0.0007 * np.sin(0.3 * t + k))) / k ** 1.7 for k in range(1, 6))
    swell = 0.5 - 0.5 * np.cos(2 * np.pi * np.clip(t / seconds, 0, 1))
    return fft_lowpass(tone, 600) * swell * level


def render(events, seconds, drones=()):
    """events: (tempo em s, nota, força, segurar, pan -1..1)."""
    n = int(seconds * RATE) + RATE * 6
    stereo = np.zeros((2, n))
    for start, note, velocity, hold, pan in events:
        sound = piano_note(note, velocity, hold)
        a = max(0, int(start * RATE))
        end = min(n, a + len(sound))
        left = np.sqrt(0.5 * (1 - pan))
        right = np.sqrt(0.5 * (1 + pan))
        stereo[0, a:end] += sound[: end - a] * left
        stereo[1, a:end] += sound[: end - a] * right
    for start, note, length, level in drones:
        tone = drone(note, length, level)
        a = int(start * RATE)
        end = min(n, a + len(tone))
        stereo[:, a:end] += tone[: end - a]
    return reverb(stereo)


def loop_and_save(stereo, seconds, name, tail_fade=6.0):
    """Faz o loop: o rabo do reverb que passa do fim volta por cima do começo."""
    n = int(seconds * RATE)
    body = stereo[:, :n].copy()
    tail = stereo[:, n:]
    body[:, : tail.shape[1]] += tail[:, : min(tail.shape[1], n)]
    # Tira o ronco abaixo de ~40 Hz (batida do martelo e tapete) que só embola o som.
    for side in range(2):
        spectrum = np.fft.rfft(body[side])
        freqs = np.fft.rfftfreq(n, 1.0 / RATE)
        spectrum *= 1.0 / np.sqrt(1.0 + (40.0 / np.maximum(freqs, 1.0)) ** 4)
        body[side] = np.fft.irfft(spectrum, n)
    body /= np.max(np.abs(body)) / 0.8
    pcm = (np.clip(body.T, -1, 1) * 32767).astype("<i2")
    os.makedirs(MUSIC, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        wav_path = os.path.join(tmp, name + ".wav")
        with wave.open(wav_path, "wb") as w:
            w.setnchannels(2)
            w.setsampwidth(2)
            w.setframerate(RATE)
            w.writeframes(pcm.tobytes())
        target = os.path.join(MUSIC, name + ".ogg")
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav_path, "-c:a", "libvorbis", "-q:a", "5", target], check=True)
    print("  " + name + ".ogg", "%.0f s" % seconds)


def human(x, amount=0.025):
    return x + rng.uniform(-amount, amount)


def menu_theme():
    """Tema do menu: Ré menor, 54 bpm, frases curtas com respiro; a melodia some e volta."""
    beat = 60.0 / 54
    bar = 4 * beat
    # (baixo, acorde da mão esquerda, melodia [(tempo no compasso, nota, força)])
    plan = [
        ("D2", ["A2", "F3"], [(2.0, "A4", 0.42), (3.0, "F4", 0.36)]),
        ("Bb1", ["F2", "D3"], [(0.5, "E4", 0.38), (2.0, "D4", 0.4)]),
        ("G1", ["D2", "Bb2"], [(1.0, "Bb3", 0.36), (2.5, "C4", 0.34), (3.0, "D4", 0.4)]),
        ("A1", ["E2", "C#3"], [(2.0, "E4", 0.36)]),
        ("D2", ["A2", "F3"], [(0.0, "D5", 0.4), (1.5, "C5", 0.35), (2.0, "A4", 0.38)]),
        ("F1", ["C2", "A2"], [(1.0, "G4", 0.36), (2.0, "F4", 0.38), (3.5, "E4", 0.3)]),
        ("G1", ["D2", "Bb2"], [(0.0, "D4", 0.4), (2.0, "Bb3", 0.34)]),
        ("A1", ["E2", "G2"], []),
        ("D2", ["A2", "E3"], [(2.0, "F4", 0.34)]),
        ("Bb1", ["F2", "D3"], [(1.0, "A4", 0.4), (2.0, "G4", 0.34), (3.0, "F4", 0.32)]),
        ("C2", ["G2", "E3"], [(0.5, "E4", 0.36), (2.0, "C4", 0.3)]),
        ("A1", ["E2", "C#3"], [(1.0, "A3", 0.3)]),
        ("D2", ["A2", "F3"], []),
        ("D2", ["A2", "D3"], []),
    ]
    events = []
    drones = []
    for i, (bass, chord, melody) in enumerate(plan):
        start = i * bar
        events.append((human(start), bass, human(0.5, 0.05), bar * 1.9, -0.25))
        events.append((human(start), bass[:-1] + str(int(bass[-1]) + 1), 0.28, bar * 1.6, -0.2))
        for j, note in enumerate(chord):
            events.append((human(start + beat * (1 + j * 0.5)), note, human(0.3, 0.04), bar * 1.4, -0.1 + 0.1 * j))
        for at, note, velocity in melody:
            events.append((human(start + at * beat, 0.04), note, velocity, beat * 2.6, 0.25))
        if i % 4 == 0:
            drones.append((start, bass[:-1] + "2" if int(bass[-1]) < 2 else bass, bar * 4.2, 0.022))
    seconds = len(plan) * bar
    loop_and_save(render(events, seconds, drones), seconds, "menu_piano")


def world_theme():
    """No mundo: quase só silêncio e vento; notas graves isoladas, um acorde de vez em quando."""
    beat = 60.0 / 48
    events = []
    phrases = [
        (0.0, [("D2", 0.42, 9.0), ("A2", 0.3, 8.0)], [(3.0, "F4", 0.3), (5.0, "E4", 0.26)]),
        (22.0, [("Bb1", 0.4, 9.0), ("F2", 0.28, 8.0)], [(2.5, "D4", 0.28)]),
        (44.0, [("G1", 0.38, 9.0), ("D2", 0.3, 8.0), ("Bb2", 0.24, 7.0)], [(4.0, "A3", 0.26), (6.0, "Bb3", 0.24)]),
        (70.0, [("A1", 0.4, 10.0), ("E2", 0.28, 9.0)], [(3.0, "C#4", 0.24), (6.5, "E4", 0.22)]),
        (96.0, [("D2", 0.36, 10.0), ("F2", 0.24, 9.0), ("A2", 0.22, 9.0)], []),
    ]
    for start, chord, melody in phrases:
        for k, (note, velocity, hold) in enumerate(chord):
            events.append((human(start + k * beat * 0.75, 0.05), note, velocity, hold, -0.2 + 0.15 * k))
        for at, note, velocity in melody:
            events.append((human(start + at * beat, 0.05), note, velocity, beat * 3.0, 0.3))
    seconds = 124.0
    loop_and_save(render(events, seconds, [(0.0, "D2", 60.0, 0.018), (62.0, "A1", 60.0, 0.018)]), seconds, "mundo_piano")


if __name__ == "__main__":
    if subprocess.run(["ffmpeg", "-version"], capture_output=True).returncode != 0:
        sys.exit("Precisa do ffmpeg no PATH.")
    print("Piano:")
    menu_theme()
    world_theme()
