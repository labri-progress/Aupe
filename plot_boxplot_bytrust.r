#!/usr/bin/env Rscript
# Usage: Rscript plot_boxplot_bytrust.r <budget> <faulty_pct> [strategy] [t_count] [p_merge] [attack_start]
# Example: Rscript plot_boxplot_bytrust.r 6.0 10 decay 200 1 10000
#
# Lit le fichier per-node CSV, classe chaque noeud en "Honest" ou "Trusted",
# et produit des boxplots (un panneau par metrique) a des snapshots de rounds :
#   - Nombre de decays (division)
#   - F1 score
#   - TP (byzantins identifies)
#   - Bias factor error
#
# Output: results/boxplots_trust_<strat>_f<faulty>_b<budget>_x<t_count>.pdf

args <- commandArgs(trailingOnly = TRUE)

library(ggplot2)
library(dplyr)
library(gridExtra)

# ── Parametres ────────────────────────────────────────────────────────────────
budget       <- as.numeric(args[1])
faulty_pct   <- as.integer(args[2])
strategy     <- if (length(args) >= 3) as.character(args[3]) else "decay"
t_count      <- if (length(args) >= 4) as.integer(args[4]) else 200
p_merge      <- if (length(args) >= 5) as.integer(args[5]) else 1
attack_start <- if (length(args) >= 6) as.integer(args[6]) else 10000

nodes        <- 1000
view         <- 20
faulty_count <- as.integer(nodes * faulty_pct / 100)
results_dir  <- "results_merge"

# Rounds cibles : 9999 = juste avant l'attaque, 10500 = juste apres
#target_times <- c(5000, 9999, 10500, 15000, 20000)
target_times <- c(100, 200, 300, 500, 800, 1000)
# ── Lecture ───────────────────────────────────────────────────────────────────
fname <- file.path(results_dir,
  sprintf("nodes-%s-%d-%d-%d-%d-%d-%.1f.csv",
    strategy, nodes, view, faulty_count, t_count, p_merge, budget))

if (!file.exists(fname)) {
  cat("Fichier introuvable:", fname, "\n")
  cat("Fichiers disponibles dans", results_dir, ":\n")
  cat(paste(list.files(results_dir, pattern = "\\.csv$"), collapse = "\n"), "\n")
  quit(status = 1)
}
cat("Lecture:", fname, "\n")

d <- read.table(fname, header = TRUE)
d$time    <- as.integer(d$time)
d$node_id <- as.integer(d$node_id)

# ── Selection des snapshots ───────────────────────────────────────────────────
available  <- sort(unique(d$time))
snap_times <- unique(sapply(target_times,
  function(t) available[which.min(abs(available - t))]))
snap_times <- sort(snap_times)

cat("Rounds utilises:", paste(snap_times, collapse = ", "), "\n")
d <- d[d$time %in% snap_times, ]

# ── Classification des noeuds (exclut les Byzantins node_id < faulty_count) ───
d <- d[d$node_id >= faulty_count, ]
d$group <- ifelse(d$node_id < faulty_count + t_count, "Trusted", "Honest")

if (t_count == 0 || sum(d$group == "Trusted") == 0) {
  cat("Aucun noeud Trusted (t_count=0 ou absent). Abandon.\n")
  quit(status = 1)
}

# ── Extraction des metriques selon le groupe ──────────────────────────────────
d$division <- ifelse(d$group == "Trusted", d$t_division, d$h_division)
d$f1       <- ifelse(d$group == "Trusted", d$t_f1,       d$h_f1)
d$tp       <- ifelse(d$group == "Trusted", d$t_tp,       d$h_tp)
d$biasErr  <- ifelse(d$group == "Trusted", d$t_biasErr,  d$h_biasErr)

d$group <- factor(d$group, levels = c("Honest", "Trusted"))

# ── Labels des rounds ─────────────────────────────────────────────────────────
time_labels <- sapply(snap_times, function(t) sprintf("%d", t))
names(time_labels) <- as.character(snap_times)

d$time_f <- factor(d$time,
  levels = snap_times,
  labels = time_labels[as.character(snap_times)])

# ── Couleurs & theme ──────────────────────────────────────────────────────────
group_colors  <- c("Honest" = "#E69F00", "Trusted" = "#56B4E9")
group_borders <- c("Honest" = "#B07800", "Trusted" = "#1A6E9E")

mytheme <- theme(
  panel.grid.major      = element_line(color = "gray90", linewidth = 0.5),
  panel.grid.minor      = element_line(color = "gray95", linewidth = 0.25),
  panel.background      = element_rect(fill = "white"),
  plot.background       = element_rect(fill = "white"),
  panel.border          = element_rect(colour = "black", linewidth = 1, fill = NA),
  text                  = element_text(size = 12, color = "black"),
  axis.title.x          = element_text(size = 12, face = "bold"),
  axis.title.y          = element_text(size = 12, face = "bold"),
  axis.text.x           = element_text(size = 8,  face = "bold"),
  axis.text.y           = element_text(size = 10, face = "bold"),
  plot.title            = element_text(size = 11, face = "bold"),
  legend.text           = element_text(size = 10, face = "bold"),
  legend.title          = element_blank(),
  legend.position       = "bottom",
  legend.background     = element_rect(fill = "transparent", colour = NA),
  legend.box.background = element_rect(fill = "transparent", colour = NA),
  axis.ticks            = element_line(color = "black", linewidth = 1)
)

# Fond colore pour distinguer pre vs post-attaque
n_pre <- sum(snap_times < attack_start)

pre_post_bg <- annotate("rect",
  xmin = n_pre + 0.5, xmax = length(snap_times) + 0.5,
  ymin = -Inf, ymax = Inf,
  alpha = 0.06, fill = "#D55E00")

# ── Limites Y : portee des moustaches (Q1-1.5IQR … Q3+1.5IQR) + marge ────────
whisker_lim <- function(x, margin = 0.08, lo_zero = FALSE) {
  q    <- quantile(x, c(0.25, 0.75), na.rm = TRUE)
  iqr  <- q[2] - q[1]
  lo   <- q[1] - 1.5 * iqr
  hi   <- q[2] + 1.5 * iqr
  span <- hi - lo
  lo   <- lo - span * margin
  hi   <- hi + span * margin
  if (lo_zero) lo <- 0
  c(lo, hi)
}

lim_div  <- whisker_lim(d$division, lo_zero = TRUE)
lim_f1   <- c(0, 1)
lim_tp   <- c(0, faulty_count)
lim_bias <- whisker_lim(d$biasErr)

# ── Fonction generateur de panneau ────────────────────────────────────────────
make_panel <- function(metric_col, title, ylims, hline = NULL) {
  p <- ggplot(d, aes(x = time_f, y = .data[[metric_col]],
                     fill = group, color = group)) +
    pre_post_bg +
    geom_boxplot(outlier.size = 0.5, outlier.alpha = 0.4,
                 linewidth = 0.4, alpha = 0.75,
                 position = position_dodge(width = 0.8)) +
    scale_fill_manual(values  = group_colors) +
    scale_color_manual(values = group_borders) +
    coord_cartesian(ylim = ylims) +
    labs(x     = expression(bold("Round")),
         y     = NULL,
         title = bquote(bold(.(title)))) +
    mytheme
  if (!is.null(hline))
    p <- p + geom_hline(yintercept = hline, linetype = "dashed",
                        color = "gray40", linewidth = 0.6)
  p
}

# ── 4 panneaux ────────────────────────────────────────────────────────────────
p_div  <- make_panel("division", "Decays (division count)", ylims = lim_div)
p_f1   <- make_panel("f1",      "F1 score",                ylims = lim_f1)
p_tp   <- make_panel("tp",      "TP (byz. identifies)",    ylims = lim_tp)
p_bias <- make_panel("biasErr", "Bias factor error",       ylims = lim_bias, hline = 0)

panels_no_legend <- lapply(list(p_div, p_f1, p_tp, p_bias),
  function(p) p + theme(legend.position = "none"))

# ── Titre global ──────────────────────────────────────────────────────────────
budget = 0.5
t_pct      <- t_count / nodes * 100
main_title <- sprintf(
  "%s  |  N=%d  f=%d (%.0f%%)  x=%d (%.0f%%) trusted  budget=%.1f KB  attack@t=%d",
  toupper(strategy), nodes, faulty_count, faulty_pct,
  t_count, t_pct, budget, attack_start)

# ── Sauvegarde ────────────────────────────────────────────────────────────────
dir.create("results", showWarnings = FALSE)
outfile <- sprintf("results/boxplots_trust_%s_f%d_b%.1f_x%d.pdf",
  strategy, faulty_count, budget, t_count)

if (requireNamespace("cowplot", quietly = TRUE)) {
  library(cowplot)
  legend_grob <- get_legend(
    p_div + theme(legend.position    = "right",
                  legend.direction   = "vertical",
                  legend.text        = element_text(size = 12, face = "bold")))
  row1  <- plot_grid(plotlist = panels_no_legend, nrow = 1, rel_widths = rep(1, 4))
  full  <- plot_grid(row1, legend_grob, nrow = 1, rel_widths = c(4, 0.35))
  title_p <- ggdraw() + draw_label(main_title, fontface = "bold", size = 10)
  final <- plot_grid(title_p, full, ncol = 1, rel_heights = c(0.07, 1))
  ggsave(outfile, final, width = 15, height = 5)
} else {
  pdf(outfile, width = 15, height = 5)
  grid.arrange(
    grobs = c(panels_no_legend,
              list(grid::textGrob(main_title,
                                  gp = grid::gpar(fontface = "bold", cex = 0.8)))),
    layout_matrix = rbind(c(5, 5, 5, 5), c(1, 2, 3, 4)),
    heights = c(0.1, 1))
  dev.off()
}

cat("Sauvegarde dans:", outfile, "\n")
