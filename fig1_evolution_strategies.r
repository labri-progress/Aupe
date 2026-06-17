#!/usr/bin/env Rscript
# Usage: Rscript fig1_evolution_strategies.r <budget> [zoom_from zoom_to]
#
# Grille 2x2 — évolution de la proportion de byzantins dans la vue des
# nœuds corrects en fonction des rounds pour trois stratégies :
#   Aupe Array   (array,  sans budget)
#   Aupe BM      (bm,     avec budget y)
#   Aupe BMDecay (decay2, avec budget y, sans nœuds de confiance)
# Faulty proportions étudiées : 10, 20, 30, 40 %
# Attaque : 20 000 rounds, début au round 10 000
#
# Zoom : fournir zoom_from et zoom_to pour afficher une fenêtre resserrée
# avec un pas de temps plus fin (time_step = 5 au lieu de 100).

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1) { cat("Usage: Rscript fig1_evolution_strategies.r <budget> [zoom_from zoom_to]\n"); quit(status = 1) }

library(ggplot2)
library(dplyr)
library(gridExtra)

# ── Paramètres ────────────────────────────────────────────────────────────────
budget    <- as.numeric(args[1])
zoom_from <- if (length(args) >= 2) as.integer(args[2]) else 0L
zoom_to   <- if (length(args) >= 3) as.integer(args[3]) else 0L
zoomed    <- zoom_from > 0

nodes       <- 1000
view        <- 20
nruns       <- 1
faulty_pcts <- c(10, 20, 30, 40)
results_dir <- "output_byz"

time_step <- if (zoomed) 5 else 100
line_size <- 0.5
width     <- 10
height    <- 5   # par panneau → PDF final = 10 x 10 (2 rangées)

# ── Thème ─────────────────────────────────────────────────────────────────────
mytheme <- theme(
  panel.grid.major        = element_line(color = "gray90",  linewidth = 0.50),
  panel.grid.minor        = element_line(color = "gray95",  linewidth = 0.25),
  panel.background        = element_rect(fill = "white"),
  plot.background         = element_rect(fill = "white"),
  panel.border            = element_rect(colour = "black", linewidth = 1, fill = NA),
  legend.spacing.y        = unit(0.005, "cm"),
  text                    = element_text(size = 12, color = "black"),
  axis.title.x            = element_text(size = 13, face = "bold"),
  axis.title.y            = element_text(size = 12, face = "bold"),
  axis.text.x             = element_text(size = 12, face = "bold"),
  axis.text.y             = element_text(size = 12, face = "bold"),
  plot.title              = element_text(size = 13, face = "bold"),
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

# ── Palette cohérente (Okabe-Ito + accord avec les autres scripts) ─────────────
custom_colors <- c(
  "Aupe Array"   = "#56B4E9",   # bleu ciel
  "Aupe BM"      = "#882EE6",   # violet
  "Aupe BMDecay" = "#000000"    # noir
)
custom_lty <- c(
  "Aupe Array"   = "solid",
  "Aupe BM"      = "solid",
  "Aupe BMDecay" = "solid"
)
level_order <- c("Aupe Array", "Aupe BM", "Aupe BMDecay")

# ── Lecture d'un fichier résultat ─────────────────────────────────────────────
read_file <- function(fname, label, f_pct, run) {
  if (!file.exists(fname)) {
    cat("Warning: fichier absent:", fname, "\n")
    return(NULL)
  }
  d <- read.table(fname, header = TRUE)
  d <- d[, c("time", "avgByzN"), drop = FALSE]
  d$time     <- as.integer(d$time)
  d$strategy <- label
  d$f_pct    <- f_pct
  d$run      <- run
  if (zoomed) d <- d[d$time >= zoom_from & d$time <= zoom_to, ]
  d
}

# ── Chargement de toutes les stratégies ───────────────────────────────────────
load_all <- function() {
  df <- data.frame()
  for (f_pct in faulty_pcts) {
    f <- as.integer(nodes * f_pct / 100)
    for (run in 1:nruns) {
      # Aupe Array (pas de budget)
      fn <- file.path(results_dir, sprintf("array-N%d-v%d-f%d-run%d", nodes, view, f, run))
      d  <- read_file(fn, "Aupe Array", f_pct, run)
      if (!is.null(d)) df <- rbind(df, d)
      # Aupe BM
      fn <- file.path(results_dir, sprintf("bm-N%d-v%d-f%d-y%g-run%d", nodes, view, f, budget, run))
      d  <- read_file(fn, "Aupe BM", f_pct, run)
      if (!is.null(d)) df <- rbind(df, d)
      # Aupe BMDecay (decay2, sans noeuds de confiance)
      fn <- file.path(results_dir, sprintf("decay2-N%d-v%d-f%d-y%g-run%d", nodes, view, f, budget, run))
      d  <- read_file(fn, "Aupe BMDecay", f_pct, run)
      if (!is.null(d)) df <- rbind(df, d)
    }
  }
  df
}

# ── Agrégation (moyenne inter-runs, sous-échantillonnage) ─────────────────────
prepare <- function(df) {
  df$propByz <- df$avgByzN / view
  avg <- df %>%
    group_by(strategy, f_pct, time) %>%
    summarise(propByz = mean(propByz), .groups = "drop") %>%
    filter(time %% time_step == 0)
  present <- intersect(level_order, unique(avg$strategy))
  avg$strategy <- factor(avg$strategy, levels = present)
  avg
}

# ── Axe X : ticks adaptés à la fenêtre d'affichage ──────────────────────────
if (zoomed) {
  x_range  <- seq(zoom_from, zoom_to, by = max(1, (zoom_to - zoom_from) %/% 5))
  x_breaks <- x_range
  x_labels <- as.character(x_breaks)
} else {
  x_breaks <- c(0, 5000, 10000, 15000, 20000)
  x_labels <- c("0", "5K", "10K", "15K", "20K")
}

# ── Construction d'un panneau ─────────────────────────────────────────────────
byz_plot <- function(data, f, show_legend = FALSE, show_y_title = TRUE) {
  optimal <- f / 100
  ggplot(data, aes(x = time, y = propByz,
                   color = strategy, linetype = strategy, group = strategy)) +
    geom_hline(yintercept = optimal, linetype = "dashed", color = "gray50", linewidth = 0.5) +
    geom_vline(xintercept = 10000,   linetype = "dotted", color = "gray50", linewidth = 0.5) +
    geom_line(linewidth = line_size) +
    scale_color_manual(values = custom_colors,  drop = FALSE) +
    scale_linetype_manual(values = custom_lty,  drop = FALSE) +
    labs(
      x     = expression(bold("Rounds")),
      y     = if (show_y_title) expression(bold("Proportion byz. dans la vue")) else NULL,
      title = sprintf("f = %d%%", f)
    ) +
    coord_cartesian(ylim = c(0, 1)) +
    scale_x_continuous(
      breaks    = x_breaks,
      labels    = x_labels,
      sec.axis  = dup_axis(labels = NULL, name = NULL)
    ) +
    scale_y_continuous(
      breaks       = seq(0, 1, by = 0.2),
      minor_breaks = seq(0, 1, by = 0.1),
      sec.axis     = dup_axis(labels = NULL, name = NULL)
    ) +
    mytheme +
    theme(legend.position = if (show_legend) c(0.68, 0.80) else "none") +
    guides(color    = guide_legend(ncol = 1),
           linetype = guide_legend(ncol = 1))
}

# ── Production de la grille ───────────────────────────────────────────────────
raw <- load_all()
if (nrow(raw) == 0) { cat("Aucune donnée chargée. Vérifiez les fichiers dans", results_dir, "\n"); quit(status = 1) }
avg <- prepare(raw)

plots <- vector("list", length(faulty_pcts))
for (i in seq_along(faulty_pcts)) {
  f   <- faulty_pcts[i]
  sub <- avg %>% filter(f_pct == f)
  plots[[i]] <- byz_plot(sub, f,
                          show_legend  = (i == 2),           # légende panneau haut-droite
                          show_y_title = (i %% 2 == 1))      # titre Y panneau gauche seulement
}

dir.create("results", showWarnings = FALSE)
zoom_tag <- if (zoomed) sprintf("-zoom%d-%d", zoom_from, zoom_to) else ""
outfile  <- sprintf("results/fig1_evolution_strategies_%gKB%s.pdf", budget, zoom_tag)

pdf(outfile, width = width, height = height * 2)
grid.arrange(grobs = plots, nrow = 2, ncol = 2)
dev.off()
cat("Sauvegarde dans:", outfile, "\n")
