#!/usr/bin/env Rscript
# Usage: Rscript fig2_convergence_summary.r <budget>
#
# Figure récapitulative — proportion de byzantins dans la vue des nœuds
# corrects à la convergence (moyenne sur les 9 000 derniers rounds, i.e.
# rounds > 11 000) en fonction du pourcentage de byzantins dans le système.
#
# Stratégies comparées :
#   Basalt       (basalt, sans budget)
#   Brahms       (brahms, sans budget)
#   Aupe BMDecay (decay2, avec budget y, sans nœuds de confiance)
#
# La ligne de référence y = f/100 correspond à une vue non-filtrée.

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1) { cat("Usage: Rscript fig2_convergence_summary.r <budget>\n"); quit(status = 1) }

library(ggplot2)
library(dplyr)

# ── Paramètres ────────────────────────────────────────────────────────────────
budget      <- as.numeric(args[1])
nodes       <- 1000
view        <- 20
nruns       <- 1
faulty_pcts <- c(10, 20, 30, 40)
conv_start  <- 11000   # moyenne sur rounds > conv_start (9 000 derniers rounds)
results_dir <- "output_byz"

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

# ── Palette (Okabe-Ito, cohérente avec les autres scripts) ────────────────────
custom_colors <- c(
  "Basalt"       = "#E69F00",   # orange
  "Brahms"       = "#D55E00",   # vermillion
  "Aupe BMDecay" = "#000000"    # noir
)
custom_lty <- c(
  "Basalt"       = "solid",
  "Brahms"       = "solid",
  "Aupe BMDecay" = "solid"
)
custom_shapes <- c(
  "Basalt"       = 16,   # cercle plein
  "Brahms"       = 17,   # triangle plein
  "Aupe BMDecay" = 15    # carré plein
)
level_order <- c("Basalt", "Brahms", "Aupe BMDecay")

# ── Lecture et calcul de la convergence ───────────────────────────────────────
read_convergence <- function(fname, label, f_pct) {
  if (!file.exists(fname)) {
    cat("Warning: fichier absent:", fname, "\n")
    return(NULL)
  }
  d <- read.table(fname, header = TRUE)
  d <- d[d$time > conv_start, "avgByzN", drop = FALSE]
  if (nrow(d) == 0) {
    cat("Warning: aucune donnée après round", conv_start, "dans", fname, "\n")
    return(NULL)
  }
  data.frame(
    strategy = label,
    f_pct    = f_pct,
    propByz  = mean(d$avgByzN) / view
  )
}

# ── Chargement des trois stratégies ───────────────────────────────────────────
load_all <- function() {
  df <- data.frame()
  for (f_pct in faulty_pcts) {
    f <- as.integer(nodes * f_pct / 100)
    for (run in 1:nruns) {
      # Basalt (sans budget)
      fn <- file.path(results_dir, sprintf("basalt-N%d-v%d-f%d-run%d", nodes, view, f, run))
      d  <- read_convergence(fn, "Basalt", f_pct)
      if (!is.null(d)) df <- rbind(df, d)
      # Brahms (sans budget)
      fn <- file.path(results_dir, sprintf("brahms-N%d-v%d-f%d-run%d", nodes, view, f, run))
      d  <- read_convergence(fn, "Brahms", f_pct)
      if (!is.null(d)) df <- rbind(df, d)
      # Aupe BMDecay (decay2, sans trusted)
      fn <- file.path(results_dir, sprintf("decay2-N%d-v%d-f%d-y%g-run%d", nodes, view, f, budget, run))
      d  <- read_convergence(fn, "Aupe BMDecay", f_pct)
      if (!is.null(d)) df <- rbind(df, d)
    }
  }
  df
}

# ── Agrégation inter-runs ─────────────────────────────────────────────────────
raw <- load_all()
if (nrow(raw) == 0) { cat("Aucune donnée chargée.\n"); quit(status = 1) }

avg <- raw %>%
  group_by(strategy, f_pct) %>%
  summarise(propByz = mean(propByz), .groups = "drop")

present <- intersect(level_order, unique(avg$strategy))
avg$strategy <- factor(avg$strategy, levels = present)

# ── Référence : proportion brute (y = f_pct / 100) ───────────────────────────
ref_df <- data.frame(f_pct = faulty_pcts, ref = faulty_pcts / 100)

# ── Figure ────────────────────────────────────────────────────────────────────
p <- ggplot(avg, aes(x = f_pct, y = propByz,
                     color = strategy, shape = strategy, linetype = strategy,
                     group = strategy)) +
  geom_line(data = ref_df, aes(x = f_pct, y = ref),
            inherit.aes = FALSE,
            linetype = "dashed", color = "gray50", linewidth = 0.5) +
  geom_line(linewidth = 0.7) +
  geom_point(size = 3.5) +
  scale_color_manual(values = custom_colors,  drop = FALSE) +
  scale_linetype_manual(values = custom_lty,  drop = FALSE) +
  scale_shape_manual(values = custom_shapes,  drop = FALSE) +
  scale_x_continuous(
    breaks    = faulty_pcts,
    labels    = paste0(faulty_pcts, "%"),
    sec.axis  = dup_axis(labels = NULL, name = NULL)
  ) +
  scale_y_continuous(
    breaks       = seq(0, 1, by = 0.1),
    minor_breaks = seq(0, 1, by = 0.05),
    labels       = function(x) paste0(round(x * 100), "%"),
    sec.axis     = dup_axis(labels = NULL, name = NULL)
  ) +
  coord_cartesian(ylim = c(0, 1)) +
  labs(
    x = expression(bold("% de byzantins dans le système")),
    y = expression(bold("Prop. byz. à convergence"))
  ) +
  mytheme +
  theme(legend.position = c(0.20, 0.82)) +
  guides(color    = guide_legend(ncol = 1),
         linetype = guide_legend(ncol = 1),
         shape    = guide_legend(ncol = 1))

dir.create("results", showWarnings = FALSE)
outfile <- sprintf("results/fig2_convergence_summary_%gKB.pdf", budget)
pdf(outfile, width = width, height = height)
print(p)
dev.off()
cat("Sauvegarde dans:", outfile, "\n")
