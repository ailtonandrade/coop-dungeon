"""Texturas da vila (low-poly, mas encardida): parede de tijolo com reboco caindo, contrapiso
de cimento e manchas de sujeira. Tudo emenda nas bordas (repete sem costura).
Rodar: python3 tools/gerar_texturas.py
"""
import os
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "world", "textures")
SIZE = 512
rng = np.random.default_rng(13)


def tile_noise(size, cells, octaves=4, seed=0, stretch_y=1.0):
    """Ruído suave que emenda (soma de senos/cossenos de frequências inteiras, em todas as
    direções). stretch_y < 1 deixa as manchas compridas na vertical (escorrido)."""
    r = np.random.default_rng(seed)
    y, x = np.mgrid[0:size, 0:size] / size
    out = np.zeros((size, size))
    amp = 1.0
    for o in range(octaves):
        f = cells * (2 ** o)
        for _ in range(10):
            fx = int(r.integers(-f, f + 1))
            fy = int(round(r.integers(-f, f + 1) * stretch_y))
            if fx == 0 and fy == 0:
                fx = 1
            ph = r.uniform(0, 2 * np.pi)
            out += amp * np.cos(2 * np.pi * (fx * x + fy * y) + ph)
        amp *= 0.5
    out -= out.min()
    return out / out.max()


def save(name, rgb):
    img = Image.fromarray(np.clip(rgb * 255, 0, 255).astype(np.uint8))
    img.save(os.path.join(OUT, name))
    print("  world/textures/" + name)


def wall():
    # 3 m de parede por textura: tijolo baiano/maciço 0,375 x 0,15 m (8 por fileira, 20 fileiras).
    s = SIZE
    cols, rows = 8, 20
    bw, bh = s / cols, s / rows
    y, x = np.mgrid[0:s, 0:s].astype(float)
    row = (y // bh).astype(int)
    shift = (row % 2) * (bw / 2)
    bx = ((x + shift) % bw)
    by = y % bh
    mortar = (bx < 3) | (by < 3)
    brick_id = ((x + shift) // bw).astype(int) % cols + row * cols
    tone = rng.uniform(0.82, 1.12, cols * rows + cols)[brick_id]
    brick = np.stack([0.5 * tone, 0.27 * tone, 0.19 * tone], -1)
    grain = tile_noise(s, 16, 3, 1)[..., None]
    brick *= 0.85 + 0.3 * grain
    mortar_c = np.array([0.5, 0.48, 0.44])
    base = np.where(mortar[..., None], mortar_c, brick)
    # Reboco (cimento) cobrindo boa parte, caindo em placas: onde o ruído passa do limite.
    cover = tile_noise(s, 2, 4, 2)
    plaster_mask = cover > 0.5
    edge = (cover > 0.46) & ~plaster_mask
    plaster_tone = 0.5 + 0.14 * tile_noise(s, 6, 4, 3)
    plaster = np.stack([plaster_tone * 1.0, plaster_tone * 0.96, plaster_tone * 0.86], -1)
    out = np.where(plaster_mask[..., None], plaster, base)
    out = np.where(edge[..., None], out * 0.72, out)  # beirada quebrada do reboco
    # Manchas de umidade e fuligem escorrendo (riscos verticais).
    drips = tile_noise(s, 6, 3, 4, stretch_y=0.08)
    patches = tile_noise(s, 2, 3, 5)
    stains = np.clip((drips - 0.5) * 2.5, 0, 1) * np.clip((patches - 0.3) * 2, 0, 1)
    mold = np.clip((tile_noise(s, 3, 4, 6) - 0.62) * 3, 0, 1)
    out = out * (1 - 0.5 * stains[..., None]) + np.array([0.1, 0.1, 0.07]) * 0.5 * stains[..., None]
    out = out * (1 - 0.35 * mold[..., None]) + np.array([0.16, 0.2, 0.12]) * 0.35 * mold[..., None]
    save("parede_tijolo_reboco.png", out)


def floor():
    s = SIZE
    n = tile_noise(s, 4, 5, 7)
    fine = tile_noise(s, 32, 2, 8)
    gray = 0.42 + 0.1 * n + 0.04 * fine
    out = np.stack([gray, gray * 0.98, gray * 0.93], -1)
    # Rachaduras: linhas finas onde um ruído cruza o meio.
    crack_n = tile_noise(s, 3, 4, 9)
    cracks = np.abs(crack_n - 0.5) < 0.0035
    out[cracks] *= 0.55
    # Manchas (óleo, água, sujeira).
    blot = np.clip((tile_noise(s, 3, 3, 10) - 0.62) * 3, 0, 1)
    out *= (1 - 0.35 * blot[..., None])
    save("contrapiso.png", out)


def grime():
    """Sujeira para lona e plástico: base clara com manchas e escorridos (multiplica a cor)."""
    s = 256
    n = tile_noise(s, 3, 4, 11)
    drips = tile_noise(s, 5, 3, 12, stretch_y=0.1)
    dirt = np.clip((n - 0.45) * 1.8, 0, 1) * 0.6 + np.clip((drips - 0.55) * 2, 0, 1) * 0.7
    v = np.clip(1.0 - dirt * 0.65, 0.3, 1.0)
    out = np.stack([v, v * 0.97, v * 0.9], -1)
    save("sujeira.png", out)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    wall()
    floor()
    grime()
