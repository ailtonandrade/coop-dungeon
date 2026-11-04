"""Texturas da vila (low-poly, mas encardida): parede de tijolo com reboco caindo, contrapiso
de cimento, manchas de sujeira, a tela do alambrado e o cano galvanizado enferrujado.
Tudo emenda nas bordas (repete sem costura).
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


# Parede: ~10 m por repetição (WALL_METERS), para o desenho do reboco não ficar se repetindo.
WALL_METERS = 9.75
WALL_SIZE = 2048


def wall():
    # Tijolo maciço 0,375 x 0,15 m: 26 por fileira e 65 fileiras em 9,75 m.
    s = WALL_SIZE
    cols, rows = 26, 65
    bw, bh = s / cols, s / rows
    y, x = np.mgrid[0:s, 0:s].astype(float)
    row = (y // bh).astype(int)
    shift = (row % 2) * (bw / 2)
    bx = ((x + shift) % bw)
    by = y % bh
    mortar = (bx < 4) | (by < 4)
    brick_id = ((x + shift) // bw).astype(int) % cols + row * cols
    tone = rng.uniform(0.82, 1.12, cols * rows + cols)[brick_id]
    brick = np.stack([0.5 * tone, 0.27 * tone, 0.19 * tone], -1)
    grain = tile_noise(s, 52, 3, 1)[..., None]
    brick *= 0.85 + 0.3 * grain
    mortar_c = np.array([0.5, 0.48, 0.44])
    base = np.where(mortar[..., None], mortar_c, brick)
    # Reboco (cimento) cobrindo boa parte, caindo em placas: onde o ruído passa do limite.
    cover = tile_noise(s, 4, 5, 2)
    plaster_mask = cover > 0.5
    edge = (cover > 0.46) & ~plaster_mask
    plaster_tone = 0.5 + 0.14 * tile_noise(s, 18, 4, 3)
    plaster = np.stack([plaster_tone * 1.0, plaster_tone * 0.96, plaster_tone * 0.86], -1)
    out = np.where(plaster_mask[..., None], plaster, base)
    out = np.where(edge[..., None], out * 0.72, out)  # beirada quebrada do reboco
    # Manchas de umidade e fuligem escorrendo (riscos verticais).
    drips = tile_noise(s, 18, 3, 4, stretch_y=0.08)
    patches = tile_noise(s, 5, 3, 5)
    stains = np.clip((drips - 0.5) * 2.5, 0, 1) * np.clip((patches - 0.3) * 2, 0, 1)
    mold = np.clip((tile_noise(s, 8, 4, 6) - 0.62) * 3, 0, 1)
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


def save_rgba(name, rgba):
    img = Image.fromarray(np.clip(rgba * 255, 0, 255).astype(np.uint8), "RGBA")
    img.save(os.path.join(OUT, name))
    print("  world/textures/" + name)


def chain_link():
    """Tela de alambrado: losangos de arame galvanizado (8 por repetição; no jogo a repetição
    tem 0,5 m, losango de ~6 cm). Arame com brilho no meio, nós mais grossos nos cruzamentos e
    pontos de ferrugem. Fundo transparente."""
    s = 512
    period = 64
    y, x = np.mgrid[0:s, 0:s].astype(float)
    # Distância até as duas famílias de diagonais (emendam: 512 é múltiplo de 64).
    d1 = np.abs(((x + y) % period) - period / 2) - period / 2
    d2 = np.abs(((x - y) % period) - period / 2) - period / 2
    d1 = np.abs(d1) / np.sqrt(2)
    d2 = np.abs(d2) / np.sqrt(2)
    width = 3.1
    wire1 = np.clip(1.0 - d1 / width, 0, 1)
    wire2 = np.clip(1.0 - d2 / width, 0, 1)
    knot = np.clip(1.0 - np.minimum(d1, d2) / (width * 1.6), 0, 1) * (np.minimum(wire1, wire2) > 0) * 1.0
    alpha = np.clip(np.maximum(wire1, wire2) * 1.6 + knot * 0.6, 0, 1)
    shine = np.maximum(wire1, wire2) ** 2
    rust = np.clip((tile_noise(s, 6, 4, 31) - 0.55) * 3.0, 0, 1)
    grey = np.stack([0.58 + 0.3 * shine, 0.6 + 0.3 * shine, 0.62 + 0.28 * shine], -1)
    rust_color = np.stack([0.48 + 0.1 * shine, 0.27 + 0 * shine, 0.14 + 0 * shine], -1)
    rgb = grey * (1 - rust[..., None]) + rust_color * rust[..., None]
    save_rgba("alambrado.png", np.concatenate([rgb, alpha[..., None]], -1))


def rust_patches():
    """Manchas de ferrugem que multiplicam a cor (branco = limpo): ficam numa escala grande por
    cima da tela, para não repetir a cada 50 cm; escorridos para baixo."""
    s = 512
    patches = tile_noise(s, 2, 5, 41)
    drips = tile_noise(s, 6, 3, 42, stretch_y=0.08)
    amount = np.clip((patches - 0.5) * 2.2, 0, 1) + np.clip((drips - 0.6) * 2.0, 0, 1) * 0.6
    amount = np.clip(amount, 0, 1)
    clean = np.array([1.0, 1.0, 1.0])
    rust = np.array([0.78, 0.46, 0.26])
    out = clean * (1 - amount[..., None]) + rust * amount[..., None]
    save("ferrugem_manchas.png", out)


def rusty_pipe():
    """Cano galvanizado velho: cinza com manchas e escorridos de ferrugem e pontos escuros."""
    s = 512
    base = tile_noise(s, 8, 4, 51)
    patches = np.clip((tile_noise(s, 3, 5, 52) - 0.48) * 2.5, 0, 1)
    drips = np.clip((tile_noise(s, 7, 3, 53, stretch_y=0.06) - 0.55) * 2.5, 0, 1)
    pits = np.clip((tile_noise(s, 24, 2, 54) - 0.8) * 5, 0, 1)
    grey = np.stack([0.5 + base * 0.12, 0.52 + base * 0.12, 0.54 + base * 0.12], -1)
    rust = np.stack([0.42 + base * 0.1, 0.22 + base * 0.05, 0.11 + base * 0.03], -1)
    amount = np.clip(patches + drips * 0.7, 0, 1)[..., None]
    out = grey * (1 - amount) + rust * amount
    out *= (1 - pits[..., None] * 0.45)
    save("cano_enferrujado.png", out)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    wall()
    floor()
    grime()
    chain_link()
    rust_patches()
    rusty_pipe()
