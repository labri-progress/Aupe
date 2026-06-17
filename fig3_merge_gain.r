#!/usr/bin/env Rscript
# Usage: Rscript fig3_merge_gain.r <budget>
#
# Figure récapitulative — gain absolu en proportion de byzantins dans la vue
# des nœuds corrects apporté par le merge (noeuds de confiance), mesuré à
# la convergence (moyenne sur les 9 000 derniers rounds, rounds > 11 000).
#
# gain = propByz_sans_merge - propByz_avec_merge
# Un gain positif signifie que le merge réduit la présence byzantine.
#
# Stratégie de base : Aupe BMDecay sans merge (decay2)
# Variantes avec merge : t = 5 %, 10 %, 20 % de noeuds de confiance

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1) { cat("Usage: Rscript fig3_merge_gain.r <budget>\n"); quit(status = 1) }

library(ggplot2)
library(dplyr)

# ── Paramètres ────────────────────────────────────────────────────────────────
budget        <- as.numeric(args[1])
nodes         <- 1000
view          <- 20
nruns         <- 1
faulty_pcts   <- c(10, 20, 30, 40)
trusted_pcts  <- c(5, 10, 20)
conv_start    <- 11000
results_dir   <- "output_byz"

width  <- 7
height <- 5

# ── Thème ─────────────────────────────────────────────────────────────────────
mytheme <- theme(
  panel.grid.major        = element_line(color = "gray90",  linewidth = 0.50),
  panel.grid.minor        = element_line(color = "gray95",  linewidth = 0.25),
  panel.background        = element_rect(fill = "white"),
  plot.background         = element_rect(fill = "white"),
  panel.border            = element_rect(colour = "black", linewidth = 1, fill = NA),
  text                    = element_text(size = 12, color = "black"),
  axis.title.x            = element_text(size = 13, face = "bold"),
  axis.title.y            = element_text(size = 12, face = "bold"),
  axis.text.x             = element_text(size = 12, face = "bold"),
  axis.text.y             = element_text(size = 12, face = "bold"),
  legend.text             = element_text(size = 11, face = "bold"),
  legend.title            = element_blank(),
  legend.background       = element_rect(fill = "transparent", colour = NA),
  legend.box.background   = element_rect(fill = "transparent", colour = NA),
  axis.ticks              = element_line(color = "black", linewidth = 1),
  axis.ticks.length       = unit(4, "pt"),
  axis.minor.ticks.length = unit(2, "pt")
) + theme(
  axis.ticks.x.top         = element_line(color = "black", linewidth = 1),
  axis.ticks.y.right       = element_line(color = "black", linewidth = 1),
  axis.minor.ticks.x.top   = element_line(color = "black", linewidth = 0.5),
  axis.minor.ticks.y.right  = element_line(color = "black", linewidth = 0.5),
  axis.text.x.top          = element_blank(),
  axis.text.y.right        = element_blank()
)

# ── Palette (cohérente avec les autres scripts) ───────────────────────────────
merge_colors <- c(
  "t = 5%"  = "#E69F00",   # orange
  "t = 10%" = "#56B4E9",   # bleu ciel
  "t = 20%" = "#009E73"    # vert
)
merge_shapes <- c(
  "t = 5%"  = 16,
  "t = 10%" = 17,
  "t = 20%" = 15
)
merge_lty <- c(
  "t = 5%"  = "solid",
  "t = 10%" = "solid",
  "t = 20%" = "solid"
)
level_order <- paste0("t = ", trusted_pcts, "%")

# ── Lecture convergence d'un fichier ─────────────────────────────────────────
read_conv <- function(fname) {
  if (!file.exists(fname)) {
    cat("Warning: fichier absent:", fname, "\n")
    return(NA_real_)
  }
  d <- read.table(fname, header = TRUE)
  d <- d[d$time > conv_start, "avgByzN", drop = FALSE]
  if (nrow(d) == 0) return(NA_real_)
  mean(d$avgByzN) / view
}

# ── Chargement ────────────────────────────────────────────────────────────────
load_gain <- function() {
  rows <- list()
  for (f_pct in faulty_pcts) {
    f <- as.integer(nodes * f_pct / 100)
    # Convergence sans merge (baseline)
    base_vals <- numeric(nruns)
    for (run in 1:nruns) {
      fn           <- file.path(results_dir, sprintf("decay2-N%d-v%d-f%d-y%g-run%d", nodes, view, f, budget, run))
      base_vals[run] <- read_conv(fn)
    }
    base_conv <- mean(base_vals, na.rm = TRUE)
    # Convergence avec merge pour chaque t
    for (t_pct in trusted_pcts) {
      t <- as.integer(nodes * t_pct / 100)
      merge_vals <- numeric(nruns)
      for (run in 1:nruns) {
        fn              <- file.path(results_dir, sprintf("decay2-N%d-v%d-f%d-y%g-x%d-run%d", nodes, view, f, budget, t, run))
        merge_vals[run] <- read_conv(fn)
      }
      merge_conv <- mean(merge_vals, na.rm = TRUE)
      rows[[length(rows) + 1]] <- data.frame(
        strategy = paste0("t = ", t_pct, "%"),
        f_pct    = f_pct,
        gain     = base_conv - merge_conv
      )
    }
  }
  do.call(rbind, rows)
}

# ── Données ───────────────────────────────────────────────────────────────────
gain_df <- load_gain()
if (nrow(gain_df) == 0 || all(is.na(gain_df$gain))) {
  cat("Aucune donnée valide.\n"); quit(status = 1)
}
present <- intersect(level_order, unique(gain_df$strategy))
gain_df$strategy <- factor(gain_df$strategy, levels = present)

# ── Figure ────────────────────────────────────────────────────────────────────
p <- ggplot(gain_df, aes(x = f_pct, y = gain,
                          color = strategy, shape = strategy, linetype = strategy,
                          group = strategy)) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "gray50", linewidth = 0.5) +
  geom_line(linewidth = 0.7) +
  geom_point(size = 3.5) +
  scale_color_manual(values = merge_colors,  drop = FALSE) +
  scale_shape_manual(values = merge_shapes,  drop = FALSE) +
  scale_linetype_manual(values = merge_lty,  drop = FALSE) +
  scale_x_continuous(
    breaks   = faulty_pcts,
    labels   = paste0(faulty_pcts, "%"),
    sec.axis = dup_axis(labels = NULL, name = NULL)
  ) +
  scale_y_continuous(
    breaks       = seq(-0.5, 0.5, by = 0.05),
    minor_breaks = seq(-0.5, 0.5, by = 0.025),
    labels       = function(x) sprintf("%.2f", x),
    sec.axis     = dup_axis(labels = NULL, name = NULL)
  ) +
  labs(
    x = expression(bold("% de byzantins dans le système")),
    y = expression(bold("Gain en prop. byz. (sans merge − avec merge)"))
  ) +
  mytheme +
  theme(legend.position = c(0.20, 0.80)) +
  guides(color    = guide_legend(ncol = 1),
         linetype = guide_legend(ncol = 1),
         shape    = guide_legend(ncol = 1))

dir.create("results", showWarnings = FALSE)
outfile <- sprintf("results/fig3_merge_gain_%gKB.pdf", budget)
pdf(outfile, width = width, height = height)
print(p)
dev.off()
cat("Sauvegarde dans:", outfile, "\n")
