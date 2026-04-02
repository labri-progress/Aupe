#!/usr/bin/env python3
"""
Simulation runner + plotter — Aupe Byzantine-resilient peer sampling.

Courbe 1 : Séries temporelles absolues — BM, BMDecay, ER+Merge (ER × t)
Courbe 2 : Gain relatif ER+Merge vs BMDecay (état stationnaire)
Courbe 3 : Récap — byzantins dans la vue vs byzantins dans le système
"""

import subprocess, os, sys
from pathlib import Path
from concurrent.futures import ProcessPoolExecutor, as_completed

import numpy as np
import matplotlib.pyplot as plt
import matplotlib.lines as mlines

# ═══════════════════════════════════════════════════════════════════════════════
#  Configuration — modifier ici
# ═══════════════════════════════════════════════════════════════════════════════

BINARY       = "./target/debug/aupe"
N_NODES      = 1000
VIEW_SIZE    = 20
MEMORY_SIZE  = 15
N_BUCKET     = 32
NB_MERGES    = 10
FLOOD_FACTOR = 10       # facteur de flood byzantin (fixé)
ATTACK_START = 500      # round de début d'attaque
T_ROUNDS     = 3000     # rounds total
STEADY_LAST  = 500      # rounds pour la moyenne steady-state

# Grilles de paramètres
F_FRACS = [10, 20, 30, 40]   # fraction de byzantins dans le système (%)
T_FRACS = [5, 10, 20]        # fraction de nœuds de confiance (%)
ER_VALS = [20, 50, 80]       # eviction rates (%)

# Paramètres de la Courbe 1 (référence visuelle)
C1_F, C1_T = 30, 10

CACHE_DIR = Path("sim_cache")
CACHE_DIR.mkdir(exist_ok=True)

METRIC = "h_avgByzN"   # colonne utilisée pour les courbes (nœuds honnêtes)

# ═══════════════════════════════════════════════════════════════════════════════
#  Construction des commandes CLI
# ═══════════════════════════════════════════════════════════════════════════════

def _base(subcmd, n_byz, n_trusted, nb_merges, extra=None):
    cmd = [
        BINARY, "-T", str(T_ROUNDS), "-n", str(N_NODES), subcmd,
        "-n", str(N_NODES), "-t", str(n_byz),
        "-f", str(FLOOD_FACTOR), "-s", str(ATTACK_START),
        "-v", str(VIEW_SIZE), "-u", str(VIEW_SIZE),
        "-m", str(MEMORY_SIZE), "-c", str(N_BUCKET),
        "-x", str(n_trusted), "-p", str(nb_merges),
    ]
    return cmd + (extra or [])

def cmd_bm(n_byz):
    return _base("bm", n_byz, n_trusted=0, nb_merges=0)

def cmd_decay(n_byz, n_trusted):
    return _base("decay", n_byz, n_trusted, NB_MERGES)

def cmd_evict(n_byz, n_trusted, er_frac):
    return _base("evict", n_byz, n_trusted, NB_MERGES, ["-e", str(er_frac)])

# ═══════════════════════════════════════════════════════════════════════════════
#  Runner avec cache sur disque
# ═══════════════════════════════════════════════════════════════════════════════

def _cache(tag): return CACHE_DIR / f"{tag}.txt"

def _run_one(cmd, tag):
    path = _cache(tag)
    if path.exists():
        return tag, path.read_text()
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode != 0:
        raise RuntimeError(f"[{tag}] {res.stderr[:300]}")
    path.write_text(res.stdout)
    return tag, res.stdout

def run_all():
    """Lance toutes les simulations (parallèle, avec cache)."""
    jobs = []
    for f in F_FRACS:
        nb = int(f / 100 * N_NODES)
        jobs.append((cmd_bm(nb), f"bm_f{f}"))
        for t in T_FRACS:
            nt = int(t / 100 * N_NODES)
            jobs.append((cmd_decay(nb, nt), f"decay_f{f}_t{t}"))
            for er in ER_VALS:
                jobs.append((cmd_evict(nb, nt, er / 100), f"evict_f{f}_t{t}_er{er}"))

    pending = [(c, g) for c, g in jobs if not _cache(g).exists()]
    cached  = len(jobs) - len(pending)
    print(f"{len(jobs)} simulations — {cached} en cache, {len(pending)} à lancer")
    if not pending:
        return

    workers = min(os.cpu_count() or 4, len(pending))
    with ProcessPoolExecutor(max_workers=workers) as exe:
        futs = {exe.submit(_run_one, c, g): g for c, g in pending}
        for fut in as_completed(futs):
            tag = futs[fut]
            try:
                fut.result()
                print(f"  ✓ {tag}")
            except Exception as e:
                print(f"  ✗ {tag}: {e}", file=sys.stderr)

# ═══════════════════════════════════════════════════════════════════════════════
#  Parser de sortie
# ═══════════════════════════════════════════════════════════════════════════════

def parse(tag):
    """Retourne (headers: list[str], rows: list[dict[str, float]])."""
    text = _cache(tag).read_text()
    lines = [l for l in text.splitlines() if l.strip()]
    if len(lines) < 2:
        return [], []
    headers = lines[0].split()
    rows = []
    for line in lines[1:]:
        vals = line.split()
        if len(vals) != len(headers):
            continue
        row = {}
        for h, v in zip(headers, vals):
            try:
                row[h] = float(v)
            except ValueError:          # NaN, inf …
                row[h] = float("nan")
        rows.append(row)
    return headers, rows

def col(rows, key, norm=VIEW_SIZE):
    """Extrait une colonne normalisée (÷ VIEW_SIZE pour proportion)."""
    return np.array([r.get(key, float("nan")) for r in rows]) / norm

def steady(tag, key=METRIC):
    """Proportion moyenne sur les STEADY_LAST derniers rounds (état stationnaire)."""
    _, rows = parse(tag)
    tail = rows[-STEADY_LAST:] if len(rows) >= STEADY_LAST else rows
    vals = [r.get(key, float("nan")) / VIEW_SIZE for r in tail]
    return float(np.nanmean(vals))

# ═══════════════════════════════════════════════════════════════════════════════
#  Courbe 1 — Séries temporelles absolues
# ═══════════════════════════════════════════════════════════════════════════════

def plot_curve1():
    nb  = int(C1_F / 100 * N_NODES)
    _   = int(C1_T / 100 * N_NODES)   # n_trusted (pour la légende)

    fig, ax = plt.subplots(figsize=(10, 5))
    ax.axvline(ATTACK_START, color="gray", ls=":", lw=1.2, alpha=0.7,
               label=f"Début attaque (round {ATTACK_START})")
    ax.axhline(C1_F / 100, color="tomato", ls=":", lw=1.0, alpha=0.6,
               label=f"Référence aléatoire ({C1_F} %)")

    # BM
    _, rows = parse(f"bm_f{C1_F}")
    ts = [r["time"] for r in rows]
    ax.plot(ts, col(rows, METRIC), color="black", lw=2, label="BM")

    # BMDecay
    _, rows = parse(f"decay_f{C1_F}_t{C1_T}")
    ts = [r["time"] for r in rows]
    ax.plot(ts, col(rows, METRIC), color="steelblue", lw=2, ls="--",
            label=f"BMDecay  (t={C1_T} %)")

    # ER+Merge
    er_palette = plt.cm.Reds(np.linspace(0.42, 0.90, len(ER_VALS)))
    for er, c in zip(ER_VALS, er_palette):
        _, rows = parse(f"evict_f{C1_F}_t{C1_T}_er{er}")
        ts = [r["time"] for r in rows]
        ax.plot(ts, col(rows, METRIC), color=c, lw=2,
                label=f"ER={er} %+Merge  (t={C1_T} %)")

    ax.set_xlabel("Round", fontsize=12)
    ax.set_ylabel("Prop. byzantins dans la vue (nœuds honnêtes)", fontsize=11)
    ax.set_title(
        f"Courbe 1 — Valeurs absolues  "
        f"(f={C1_F} %, t={C1_T} %, flood={FLOOD_FACTOR}×)",
        fontsize=13,
    )
    ax.legend(fontsize=9)
    ax.set_ylim(bottom=0, top=C1_F / 100 * 1.4)
    ax.grid(alpha=0.3)
    fig.tight_layout()
    fig.savefig("courbe1_absolue.png", dpi=150, bbox_inches="tight")
    plt.close()
    print("→ courbe1_absolue.png")

# ═══════════════════════════════════════════════════════════════════════════════
#  Courbe 2 — Gain relatif ER+Merge vs BMDecay
# ═══════════════════════════════════════════════════════════════════════════════

def plot_curve2():
    er_colors = {20: "#f4d03f", 50: "#e67e22", 70: "#c0392b"}

    fig, axes = plt.subplots(1, len(T_FRACS), figsize=(15, 5), sharey=True)
    fig.suptitle(
        "Courbe 2 — Gain relatif ER+Merge vs BMDecay  (état stationnaire)",
        fontsize=13,
    )

    x = np.arange(len(F_FRACS))
    w = 0.22

    for ax, t in zip(axes, T_FRACS):
        for k, er in enumerate(ER_VALS):
            gains = []
            for f in F_FRACS:
                d = steady(f"decay_f{f}_t{t}")
                e = steady(f"evict_f{f}_t{t}_er{er}")
                gains.append((d - e) / d * 100 if d > 1e-9 else 0.0)

            bars = ax.bar(
                x + (k - 1) * w, gains, w,
                label=f"ER={er} %",
                color=er_colors[er], edgecolor="white", linewidth=0.4,
            )
            ax.bar_label(bars, fmt="%.1f%%", fontsize=7, padding=2)

        ax.axhline(0, color="black", lw=0.8)
        ax.set_xticks(x)
        ax.set_xticklabels([f"f={f} %" for f in F_FRACS])
        ax.set_title(f"t={t} % nœuds de confiance", fontsize=11)
        ax.set_xlabel("Fraction de byzantins (%)")
        ax.legend(fontsize=9)
        ax.grid(axis="y", alpha=0.3)

    axes[0].set_ylabel("Gain (%)  =  (BMDecay − ER+Merge) / BMDecay", fontsize=10)
    fig.tight_layout()
    fig.savefig("courbe2_gain.png", dpi=150, bbox_inches="tight")
    plt.close()
    print("→ courbe2_gain.png")

# ═══════════════════════════════════════════════════════════════════════════════
#  Courbe 3 — Récap : byzantins vue vs byzantins système
# ═══════════════════════════════════════════════════════════════════════════════

def plot_curve3():
    er_styles = {
        20: ("#f4d03f", "o", "-"),
        50: ("#e67e22", "D", "-"),
        70: ("#c0392b", "v", "-"),
    }

    fig, axes = plt.subplots(1, len(T_FRACS), figsize=(15, 5), sharey=False)
    fig.suptitle(
        "Courbe 3 — Proportion de byzantins dans la vue vs dans le système",
        fontsize=13,
    )

    for ax, t in zip(axes, T_FRACS):
        # Référence sans défense (y = x)
        ax.plot(F_FRACS, F_FRACS, "k:", lw=1.5, label="Sans défense")

        # BM
        bm_v = [steady(f"bm_f{f}") * 100 for f in F_FRACS]
        ax.plot(F_FRACS, bm_v, "ks-", lw=2, ms=7, label="BM")

        # BMDecay
        dc_v = [steady(f"decay_f{f}_t{t}") * 100 for f in F_FRACS]
        ax.plot(F_FRACS, dc_v, "b^--", lw=2, ms=7, label="BMDecay")

        # ER+Merge
        for er, (clr, mk, ls) in er_styles.items():
            ev_v = [steady(f"evict_f{f}_t{t}_er{er}") * 100 for f in F_FRACS]
            ax.plot(F_FRACS, ev_v, color=clr, marker=mk, ls=ls,
                    lw=2, ms=7, label=f"ER={er} %+Merge")

        ax.set_xticks(F_FRACS)
        ax.set_xlabel("Byzantins dans le système (%)", fontsize=10)
        ax.set_ylabel("Byzantins dans la vue — nœuds honnêtes (%)", fontsize=10)
        ax.set_title(f"t={t} % nœuds de confiance", fontsize=11)
        ax.legend(fontsize=8)
        ax.grid(alpha=0.3)
        ax.set_xlim(7, 43)
        ax.set_ylim(bottom=0)

    fig.tight_layout()
    fig.savefig("courbe3_recap.png", dpi=150, bbox_inches="tight")
    plt.close()
    print("→ courbe3_recap.png")

# ═══════════════════════════════════════════════════════════════════════════════
#  Main
# ═══════════════════════════════════════════════════════════════════════════════

if __name__ == "__main__":
    if not Path(BINARY).exists():
        sys.exit(f"Binaire introuvable : {BINARY}  (lancez `cargo build` d'abord)")

    import argparse
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--plot-only", action="store_true",
                   help="Ne relance pas les simulations, utilise le cache existant")
    p.add_argument("--curves", nargs="*", type=int, choices=[1, 2, 3], default=[1, 2, 3],
                   help="Courbes à générer (défaut : 1 2 3)")
    args = p.parse_args()

    if not args.plot_only:
        run_all()

    print("\nGénération des courbes…")
    if 1 in args.curves: plot_curve1()
    if 2 in args.curves: plot_curve2()
    if 3 in args.curves: plot_curve3()
    print("Terminé.")
