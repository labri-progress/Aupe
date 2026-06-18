#!/usr/bin/env Rscript
# Usage: Rscript fig4_attack_comparison.r <budget> [zoom_from zoom_to]
#
# Grille 2x2 (10, 20, 30, 40 % de byzantins) — comparaison de deux régimes
# d'attaque pour Aupe BMDecay, pour chaque configuration de merge :
#
#   Normal (decay2) : les byzantins participent (se camouflent) avant le
#                         round 10 000, puis lancent l'attaque.
#   Caché   (decay4) : les byzantins sont absents avant le round 10 000,
#                         puis apparaissent et attaquent simultanément.
#
# Pour chaque régime, quatre configurations de merge :
#   t = 0 %  (sans nœuds de confiance)
#   t = 5 %  t = 10 %  t = 20 %
#
# Encodage visuel :
#   Couleur       → proportion de noeuds de confiance (t %)
#   Type de ligne → régime d'attaque (Normal = solide, Caché = tiretée)
#
# Zoom : fournir zoom_from et zoom_to pour une fenêtre resserrée avec
#        un pas de temps plus fin (time_step = 5).

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1) {
  cat("Usage: Rscript fig4_attack_comparison.r <budget> [zoom_from zoom_to]\n")
  quit(status = 1)
}

library(ggplot2)
library(dplyr)
library(gridExtra)

# ── Paramètres ────────────────────────────────────────────────────────────────
budget       <- as.numeric(args[1])
zoom_from    <- if (length(args) >= 2) as.integer(args[2]) else 0L
zoom_to      <- if (length(args) >= 3) as.integer(args[3]) else 0L
zoomed       <- zoom_from > 0

nodes        <- 1000
view         <- 20
nruns        <- 1
faulty_pcts  <- c(10, 20, 30, 40)
trusted_pcts <- c(0, 20) #c(0, 5, 10, 20)
results_dir  <- "output_byz"

time_step <- if (zoomed) 5 else 100
line_size <- 0.4
width     <- 7
height    <- 2.5

# ── Thème ─────────────────────────────────────────────────────────────────────
mytheme <- theme(
  panel.grid.major        = element_line(color = "gray90",  linewidth = 0.50),
  panel.grid.minor        = element_line(color = "gray95",  linewidth = 0.25),
  panel.background        = element_rect(fill = "white"),
  plot.background         = element_rect(fill = "white"),
  panel.border            = element_rect(colour = "black", linewidth = 1, fill = NA),
  legend.spacing.y        = unit(0.005, "cm"),
  text                    = element_text(size = 9, color = "black"),
  axis.title.x            = element_text(size = 9, face = "bold"),
  axis.title.y            = element_text(size = 9, face = "bold"),
  axis.text.x             = element_text(size = 8, face = "bold"),
  axis.text.y             = element_text(size = 8, face = "bold"),
  plot.title              = element_text(size = 9, face = "bold"),
  legend.text             = element_text(size = 8, face = "bold"),
  legend.title            = element_text(size = 8, face = "bold"),
  legend.background       = element_rect(fill = "transparent", colour = NA),
  legend.box.background   = element_rect(fill = "transparent", colour = NA),
  legend.key.height       = unit(8,  "pt"),
  plot.margin             = margin(5.5, 2, 5.5, 2, "pt"),
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

# ── Palette ───────────────────────────────────────────────────────────────────
# Couleur → merge % (cohérent avec fig3)
merge_colors <- c(
  "t = 0%"  = "#000000",   # noir
  #"t = 5%"  = "#E69F00",   # orange
  #"t = 10%" = "#56B4E9",   # bleu ciel
  "t = 20%" = "#009E73"    # vert
)
# Type de ligne → régime d'attaque
attack_lty <- c(
  "Normal" = "solid",
  "Hidden"     = "dashed"
)
# Correspondance clé de fichier → label d'attaque
attack_keys <- c("Normal" = "decay2", "Hidden" = "decay4")

# ── Lecture d'un fichier résultat ─────────────────────────────────────────────
read_file <- function(fname, attack, t_pct, f_pct, run) {
  if (!file.exists(fname)) {
    cat("Warning: fichier absent:", fname, "\n")
    return(NULL)
  }
  d <- read.table(fname, header = TRUE)
  d <- d[, c("time", "avgByzN"), drop = FALSE]
  d$time    <- as.integer(d$time)
  d$attack  <- attack
  d$t_label <- paste0("t = ", t_pct, "%")
  d$f_pct   <- f_pct
  d$run     <- run
  if (zoomed) d <- d[d$time >= zoom_from & d$time <= zoom_to, ]
  d
}

# ── Chargement ────────────────────────────────────────────────────────────────
load_all <- function() {
  df <- data.frame()
  for (f_pct in faulty_pcts) {
    f <- as.integer(nodes * f_pct / 100)
    for (attack in names(attack_keys)) {
      key <- attack_keys[attack]
      for (t_pct in trusted_pcts) {
        t <- as.integer(nodes * t_pct / 100)
        for (run in 1:nruns) {
          fn <- if (t_pct == 0L) {
            file.path(results_dir,
              sprintf("%s-N%d-v%d-f%d-y%g-run%d", key, nodes, view, f, budget, run))
          } else {
            file.path(results_dir,
              sprintf("%s-N%d-v%d-f%d-y%g-x%d-run%d", key, nodes, view, f, budget, t, run))
          }
          d <- read_file(fn, attack, t_pct, f_pct, run)
          if (!is.null(d)) df <- rbind(df, d)
        }
      }
    }
  }
  df
}

# ── Agrégation ────────────────────────────────────────────────────────────────
prepare <- function(df) {
  df$propByz <- df$avgByzN / view
  avg <- df %>%
    group_by(attack, t_label, f_pct, time) %>%
    summarise(propByz = mean(propByz), .groups = "drop") %>%
    filter(time %% time_step == 0)
  avg$attack  <- factor(avg$attack,  levels = names(attack_lty))
  avg$t_label <- factor(avg$t_label, levels = paste0("t = ", trusted_pcts, "%"))
  avg
}

# ── Axe X ─────────────────────────────────────────────────────────────────────
if (zoomed) {
  x_breaks <- pretty(c(zoom_from, zoom_to), n=4) #n = 6)
  x_labels <- as.character(x_breaks)
} else {
  x_breaks <- c(0, 5000, 10000, 15000, 20000)
  x_labels <- c("0", "5K", "10K", "15K", "20K")
}

# ── Construction d'un panneau ─────────────────────────────────────────────────
byz_plot <- function(data, f, show_legend = FALSE, show_y_title = TRUE) {
  optimal <- f / 100
  p <- ggplot(data, aes(x      = time,
                        y      = propByz,
                        color  = t_label,
                        linetype = attack,
                        group  = interaction(attack, t_label))) +
    geom_hline(yintercept = optimal, linetype = "dashed",
               color = "gray60", linewidth = 0.4) +
    geom_vline(xintercept = 10000, linetype = "dotted",
               color = "gray60", linewidth = 0.4) +
    geom_line(linewidth = line_size) +
    scale_color_manual(
      #name   = "Merge (t)",
      values = merge_colors,
      drop   = FALSE
    ) +
    scale_linetype_manual(
      name   = "Attack",
      values = attack_lty,
      drop   = FALSE
    ) +
    labs(
      x     = expression(bold("Rounds")),
      y     = if (show_y_title) expression(bold("Prop. of Byz. samp.")) else NULL,
      #title = sprintf("f = %.2f", f / 100)
    ) +
    coord_cartesian(ylim = c(0, 1)) +
    scale_x_continuous(
      breaks   = x_breaks,
      #labels   = x_labels,
      sec.axis = dup_axis(labels = NULL, name = NULL)
    ) +
    scale_y_continuous(
      breaks       = seq(0, 1, by = 0.2),
      minor_breaks = seq(0, 1, by = 0.1),
      sec.axis     = dup_axis(labels = NULL, name = NULL)
    ) +
    mytheme +
    theme(legend.position = if (show_legend) c(0.67, 0.65) else "none") +
    guides(
      color    = guide_legend(#title = "Merge (t)",  
                              ncol = 1,
                              override.aes = list(linetype = "solid",
                                                  linewidth = 0.8)),
      linetype = guide_legend(title = "Attack",     ncol = 1,
                              override.aes = list(color    = "black",
                                                  linewidth = 0.8))
    )
  p
}

# ── Production de la grille ───────────────────────────────────────────────────
raw <- load_all()
if (nrow(raw) == 0) { cat("Aucune donnée chargée.\n"); quit(status = 1) }
avg <- prepare(raw)

plots <- vector("list", length(faulty_pcts))
for (i in seq_along(faulty_pcts)) {
  f   <- faulty_pcts[i]
  sub <- avg %>% filter(f_pct == f)
  plots[[i]] <- byz_plot(sub, f,
                          show_legend  = (i == 1),
                          show_y_title = (i == 1))
}

dir.create("results", showWarnings = FALSE)
zoom_tag <- if (zoomed) sprintf("-zoom%d-%d", zoom_from, zoom_to) else ""
outfile  <- sprintf("results/fig4_attack_comparison_%gKB%s.pdf", budget, zoom_tag)

grobs_out <- lapply(plots, ggplotGrob)
max_w     <- do.call(grid::unit.pmax, lapply(grobs_out, `[[`, "widths"))
grobs_out <- lapply(grobs_out, function(g) { g$widths <- max_w; g })

pdf(outfile, width = width, height = height)
grid.arrange(grobs = grobs_out, nrow = 1, ncol = 4)
dev.off()
cat("Sauvegarde dans:", outfile, "\n")
