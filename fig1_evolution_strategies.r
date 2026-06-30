#!/usr/bin/env Rscript
# Usage: Rscript fig1_evolution_strategies.r <budget> [zoom_from zoom_to]
#
# Grille 2x2 — évolution de la proportion de byzantins dans la vue des
# nœuds corrects en fonction des rounds pour trois stratégies :
#   Array   (array,  sans budget)
#   BM      (bm,     avec budget y)
#   BMDecay (decay2, avec budget y, sans nœuds de confiance)
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
library(gtable)

# ── Paramètres ────────────────────────────────────────────────────────────────
budget    <- as.numeric(args[1])
zoom_from <- if (length(args) >= 2) as.integer(args[2]) else 0L
zoom_to   <- if (length(args) >= 3) as.integer(args[3]) else 0L
zoomed    <- zoom_from > 0

source("params.r")

time_step <- 5 #if (zoomed) 5 else 100
line_size <- 0.4
width     <- 10

# ── Thème ─────────────────────────────────────────────────────────────────────
size <- 16
mytheme <- theme(
  panel.grid.major        = element_line(color = "gray90",  linewidth = 0.50),
  panel.grid.minor        = element_line(color = "gray95",  linewidth = 0.25),
  panel.background        = element_rect(fill = "white"),
  plot.background         = element_rect(fill = "white"),
  panel.border            = element_rect(colour = "black", linewidth = 1, fill = NA),
  legend.spacing.y        = unit(0.005, "cm"),
  text                    = element_text(size = size, color = "black"),
  axis.title.x            = element_text(size = size, face = "bold"),
  axis.title.y            = element_text(size = size, face = "bold"),
  axis.text.x             = element_text(size = size-2, face = "bold"),
  axis.text.y             = element_text(size = size, face = "bold"),
  plot.title              = element_text(size = size, face = "bold"),
  legend.text             = element_text(size = size, face = "bold"),
  legend.title            = element_blank(),
  legend.background       = element_rect(fill = "transparent", colour = NA),
  legend.box.background   = element_rect(fill = "transparent", colour = NA),
  legend.key.height       = unit(9,  "pt"),
  plot.margin             = margin(5.5, 0, 5.5, 0, "pt"),
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
  "Array"   = "#56B4E9",   # bleu ciel
  "BM"      = "#882EE6",   # violet
  "BMDecay" = "#000000"    # noir
)
custom_lty <- c(
  "Array"   = "solid",
  "BM"      = "solid",
  "BMDecay" = "solid"
)
level_order <- c("Array", "BM", "BMDecay")

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
      # Array (pas de budget)
      fn <- file.path(results_dir, sprintf("array-N%d-v%d-f%d-run%d", nodes, view, f, run))
      d  <- read_file(fn, "Array", f_pct, run)
      if (!is.null(d)) df <- rbind(df, d)
      # BM
      fn <- file.path(results_dir, sprintf("bm-N%d-v%d-f%d-y%g-run%d", nodes, view, f, budget, run))
      d  <- read_file(fn, "BM", f_pct, run)
      if (!is.null(d)) df <- rbind(df, d)
      # BMDecay (decay2, sans noeuds de confiance)
      fn <- file.path(results_dir, sprintf("decay2-N%d-v%d-f%d-y%g-run%d", nodes, view, f, budget, run))
      d  <- read_file(fn, "BMDecay", f_pct, run)
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
  #x_range  <- seq(zoom_from, zoom_to, by = max(1, (zoom_to - zoom_from) %/% 5))
  #x_breaks <- x_range
  x_breaks <- pretty(c(zoom_from, zoom_to), n = 3)
  x_labels <- as.character(x_breaks)
} else {
  x_breaks <- c(0, 5000, 10000, 15000, 20000)
  x_labels <- c("0", "5K", "10K", "15K", "20K")
}

# ── Construction d'un panneau ─────────────────────────────────────────────────
byz_plot <- function(data, f, show_legend = FALSE, show_y_title = TRUE, show_y_axis = TRUE) {
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
      y     = if (show_y_title) expression(bold("Prop. of Byz. samp.")) else NULL,
      #title = sprintf("f = %.2f", f / 100)
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
    theme(
      legend.position = if (show_legend) c(0.6, 0.80) else "none",
      axis.text.y     = if (show_y_axis) NULL else element_blank(),
      axis.ticks.y    = if (show_y_axis) NULL else element_blank()
    ) +
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
                          show_legend  = (i == 1),
                          show_y_title = (i == 1),
                          show_y_axis  = (i == 1))
}

dir.create("results", showWarnings = FALSE)
zoom_tag <- if (zoomed) sprintf("-zoom%d-%d", zoom_from, zoom_to) else ""
outfile  <- sprintf("results/fig1_evolution_strategies_%gKB%s.pdf", budget, zoom_tag)

grobs_out  <- lapply(plots, ggplotGrob)
panel_cols <- sapply(grobs_out, function(g) g$layout$l[g$layout$name == "panel"])
common_w   <- do.call(grid::unit.pmax,
                      Map(function(g, col) g$widths[col], grobs_out, panel_cols))
grobs_out  <- Map(function(g, col) { g$widths[col] <- common_w; g },
                  grobs_out, panel_cols)
combined   <- Reduce(gtable_cbind, grobs_out)

pdf(outfile, width = width, height = height)
grid::grid.draw(combined)
dev.off()
cat("Sauvegarde dans:", outfile, "\n")
