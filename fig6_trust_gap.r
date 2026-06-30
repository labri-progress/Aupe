#!/usr/bin/env Rscript
# Usage: Rscript fig6_trust_gap.r <budget> [round_from] [round_to]
#
# Summary figure — difference in Byzantine proportion between honest nodes and
# trusted nodes, measured as the mean over rounds [round_from, round_to]
# (default: 11000–11049, i.e. the 50 rounds immediately after the attack).
#
#   gap = mean( h_avgByzN/view - t_avgByzN/view )   over [round_from, round_to]
#
# A positive gap means trusted nodes have a less contaminated view.
#
# Strategy: Aupe BMDecay (decay2)
# Files read from output_byz:
#   decay2-N{N}-v{v}-f{F}-y{budget}-x{T}-run{run}
#
# Figure:
#   X = proportion of Byzantine nodes in the system (0.1 … 0.4)
#   Y = gap (0–1)
#   Curves = t = 5 %, t = 10 %, t = 20 %

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1) {
  cat("Usage: Rscript fig6_trust_gap.r <budget> [round_from] [round_to]\n")
  quit(status = 1)
}

library(ggplot2)
library(dplyr)

# ── Paramètres ────────────────────────────────────────────────────────────────
budget       <- as.numeric(args[1])
round_from   <- if (length(args) >= 2) as.integer(args[2]) else 11000L
round_to     <- if (length(args) >= 3) as.integer(args[3]) else 11049L

source("params.r")
strategy     <- "decay2"
trusted_pcts <- c(5, 10, 20, 30)

cat(sprintf("Budget=%.1f  rounds [%d, %d]\n", budget, round_from, round_to))


# ── Palette cohérente avec les autres scripts ─────────────────────────────────
t_colors <- c(
  "t = 5%"  = "#E69F00",   # orange
  "t = 10%" = "#56B4E9",   # sky blue
  "t = 20%" = "#009E73",   # green
  "t = 30%" = "#CC79A7"    # rose
)
t_shapes <- c(
  "t = 5%"  = 16,
  "t = 10%" = 17,
  "t = 20%" = 15,
  "t = 30%" = 18
)
t_lty <- c(
  "t = 5%"  = "solid",
  "t = 10%" = "solid",
  "t = 20%" = "solid",
  "t = 30%" = "solid"
)
level_order <- paste0("t = ", trusted_pcts, "%")

# ── Lecture du gap h_avgByzN − t_avgByzN ─────────────────────────────────────
read_gap <- function(fname) {
  if (!file.exists(fname)) {
    cat("Warning: missing file:", fname, "\n")
    return(NA_real_)
  }
  d <- read.table(fname, header = TRUE)

  # Vérification des colonnes nécessaires
  if (!all(c("h_avgByzN", "t_avgByzN") %in% names(d))) {
    cat("Warning: columns h_avgByzN or t_avgByzN absent in", basename(fname), "\n")
    return(NA_real_)
  }

  d_win <- d[d$time >= round_from & d$time <= round_to, ]
  n_found <- nrow(d_win)
  if (n_found == 0) {
    cat(sprintf("Warning: no rounds in [%d, %d] in %s\n",
                round_from, round_to, basename(fname)))
    return(NA_real_)
  }
  if (n_found < (round_to - round_from + 1)) {
    cat(sprintf("Info: %d/%d rounds in [%d,%d] (%s)\n",
                n_found, round_to - round_from + 1,
                round_from, round_to, basename(fname)))
  }

  mean((d_win$h_avgByzN - d_win$t_avgByzN) / view, na.rm = TRUE)
}

# ── Chargement de toutes les combinaisons ─────────────────────────────────────
rows <- list()
for (f_pct in faulty_pcts) {
  f <- as.integer(nodes * f_pct / 100)
  for (t_pct in trusted_pcts) {
    t <- as.integer(nodes * t_pct / 100)
    gap_vals <- numeric(nruns)
    for (run in 1:nruns) {
      fname <- file.path(results_dir,
        sprintf("%s-N%d-v%d-f%d-y%g-x%d-run%d",
                strategy, nodes, view, f, budget, t, run))
      gap_vals[run] <- read_gap(fname)
    }
    gap_mean <- mean(gap_vals, na.rm = TRUE)
    if (!is.na(gap_mean)) {
      rows[[length(rows) + 1]] <- data.frame(
        f_pct   = f_pct,
        t_label = paste0("t = ", t_pct, "%"),
        gap     = gap_mean
      )
      cat(sprintf("  f=%d%% t=%d%% → gap = %.4f\n", f_pct, t_pct, gap_mean))
    }
  }
}

if (length(rows) == 0) {
  cat("No valid data found. Check decay2-*-x* files in", results_dir, "\n")
  quit(status = 1)
}

df <- do.call(rbind, rows)
df$t_label <- factor(df$t_label, levels = level_order)
present    <- intersect(level_order, unique(df$t_label))
df$t_label <- factor(df$t_label, levels = present)

# ── Figure ────────────────────────────────────────────────────────────────────
p <- ggplot(df, aes(x = f_pct / 100, y = gap,
                    color = t_label, shape = t_label, linetype = t_label,
                    group = t_label)) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "gray50", linewidth = 0.4) +
  geom_line(linewidth = 0.5) +
  geom_point(size = 2.0) +
  scale_color_manual(values = t_colors, drop = FALSE) +
  scale_shape_manual(values = t_shapes, drop = FALSE) +
  scale_linetype_manual(values = t_lty,  drop = FALSE) +
  scale_x_continuous(
    breaks       = faulty_pcts / 100,
    minor_breaks = NULL,
    sec.axis     = dup_axis(labels = NULL, name = NULL)
  ) +
  scale_y_continuous(
    breaks       = seq(-0.5, 0.5, by = 0.1),
    minor_breaks = seq(-0.5, 0.5, by = 0.05),
    sec.axis     = dup_axis(labels = NULL, name = NULL)
  ) +
  coord_cartesian(ylim = c(
    min(0, floor(min(df$gap, na.rm = TRUE) / 0.05) * 0.05 - 0.05),
    max(0, ceiling(max(df$gap, na.rm = TRUE) / 0.05) * 0.05 + 0.05)
  )) +
  labs(
    x = expression(bold("Proportion of Byzantine nodes")),
    y = expression(bold("View gap (honest - trusted)"))
  ) +
  mytheme +
  theme(legend.position = c(0.20, 0.80)) +
  guides(color    = guide_legend(ncol = 1),
         shape    = guide_legend(ncol = 1),
         linetype = guide_legend(ncol = 1))

dir.create("results", showWarnings = FALSE)
outfile <- sprintf("results/fig6_trust_gap_%gKB_%d-%d.pdf",
                   budget, round_from, round_to)
pdf(outfile, width = 3.5, height = height)
print(p)
dev.off()
cat("Saved:", outfile, "\n")
