#!/usr/bin/env Rscript
# Usage: Rscript plot_slots_bytrust.r <budget> <faulty_pct> [strategy] [t_count] [p_merge] [attack_start]
# Example: Rscript plot_slots_bytrust.r 6.0 10 decay 200 1 10000
#
# Lit le fichier per-node CSV, classe chaque noeud en "Honest" ou "Trusted",
# et produit deux rangees de 3 panneaux (un par categorie de slot) :
#   Rangee 1 – evolution en moyenne (courbes Honest vs Trusted) sur tous les rounds
#   Rangee 2 – boxplots a des snapshots de rounds
#
# Categories de slots (fraction des slots occupes du sketch) :
#   sl_byz  : slots occupes uniquement par des IDs byzantins
#   sl_hon  : slots occupes uniquement par des IDs honnetes
#   sl_mix  : slots avec collision byz + honnete
#
# Output: results/boxplots_slots_<strat>_f<faulty>_b<budget>_x<t_count>.pdf

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

target_times <- c(5000, 9999, 10500, 15000, 20000)

# ── Lecture ───────────────────────────────────────────────────────────────────
if (strategy == "decay3") {
  fname <- file.path(results_dir,
    sprintf("nodes-%s-%d-%d-%d-%d-%d-%.1f.csv",
      strategy, nodes, view, faulty_count, t_count, p_merge, budget))
} else if (strategy == "array") {
  fname <- file.path(results_dir,
    sprintf("nodes-%s-%d-%d-%d-%d-%d.csv",
      strategy, nodes, view, faulty_count, t_count, p_merge))
} else {
  cat("Strategie inconnue:", strategy, "\n"); quit(status = 1)
}

if (!file.exists(fname)) {
  cat("Fichier introuvable:", fname, "\n")
  cat("Fichiers disponibles dans", results_dir, ":\n")
  cat(paste(list.files(results_dir, pattern = "\\.csv$"), collapse = "\n"), "\n")
  quit(status = 1)
}
cat("Lecture:", fname, "\n")

d_raw <- read.table(fname, header = TRUE)
d_raw$time    <- as.integer(d_raw$time)
d_raw$node_id <- as.integer(d_raw$node_id)

# ── Vérification des colonnes de slots ────────────────────────────────────────
slot_cols <- c("h_sl_byz", "h_sl_hon", "h_sl_mix", "t_sl_byz", "t_sl_hon", "t_sl_mix")
missing   <- slot_cols[!slot_cols %in% names(d_raw)]
if (length(missing) > 0) {
  cat("\n[ERREUR] Les colonnes suivantes sont absentes du CSV :\n")
  cat(" ", paste(missing, collapse = ", "), "\n")
  cat("\nCe CSV a été généré avant l'ajout des métriques de slots.\n")
  cat("Regénérez les données avec la version actuelle du binaire :\n\n")
  cat(sprintf(
    "  cargo run --release -- -T <steps> -n %d decay -t %d -v 20 -u 20 -m <mem> -n %d -y %.1f -p %d ...\n\n",
    nodes, faulty_count, nodes, budget, p_merge))
  quit(status = 1)
}

# Exclure les byzantins
d_raw <- d_raw[d_raw$node_id >= faulty_count, ]
d_raw$group <- ifelse(d_raw$node_id < faulty_count + t_count, "Trusted", "Honest")

if (t_count == 0 || sum(d_raw$group == "Trusted") == 0) {
  cat("Aucun noeud Trusted (t_count=0 ou absent). Les courbes Trusted seront vides.\n")
}

# Helper : colonne ou NA
col_or_na <- function(df, nm) if (nm %in% names(df)) df[[nm]] else rep(NA_real_, nrow(df))

# Chaque noeud utilise les colonnes de son groupe
d_raw$sl_byz <- ifelse(d_raw$group == "Trusted",
                       col_or_na(d_raw, "t_sl_byz"), col_or_na(d_raw, "h_sl_byz"))
d_raw$sl_hon <- ifelse(d_raw$group == "Trusted",
                       col_or_na(d_raw, "t_sl_hon"), col_or_na(d_raw, "h_sl_hon"))
d_raw$sl_mix <- ifelse(d_raw$group == "Trusted",
                       col_or_na(d_raw, "t_sl_mix"), col_or_na(d_raw, "h_sl_mix"))

d_raw$group <- factor(d_raw$group, levels = c("Honest", "Trusted"))

# ── Theme & couleurs ──────────────────────────────────────────────────────────
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

# Fond orange apres l'attaque (pour la rangee boxplot)
available  <- sort(unique(d_raw$time))
snap_times <- unique(sapply(target_times,
  function(t) available[which.min(abs(available - t))]))
snap_times <- sort(snap_times)
cat("Snapshots utilises:", paste(snap_times, collapse = ", "), "\n")

n_pre <- sum(snap_times < attack_start)
pre_post_bg <- annotate("rect",
  xmin = n_pre + 0.5, xmax = length(snap_times) + 0.5,
  ymin = -Inf, ymax = Inf,
  alpha = 0.06, fill = "#D55E00")

# ── Rangee 1 : evolution en moyenne ──────────────────────────────────────────
avg_data <- d_raw %>%
  group_by(group, time) %>%
  summarise(sl_byz = mean(sl_byz, na.rm = TRUE),
            sl_hon = mean(sl_hon, na.rm = TRUE),
            sl_mix = mean(sl_mix, na.rm = TRUE),
            .groups = "drop")

max_time <- max(avg_data$time)
x_breaks <- if (max_time > 2000) seq(0, max_time, by = 2000) else
            if (max_time > 200)  seq(0, max_time, by = 200)  else
            sort(unique(avg_data$time))

attack_vline <- geom_vline(xintercept = attack_start, linetype = "dashed",
                           color = "#D55E00", linewidth = 0.7)

make_evo_panel <- function(metric_col, title, hline = NULL) {
  p <- ggplot(avg_data, aes(x = time, y = .data[[metric_col]],
                             color = group, group = group)) +
    attack_vline +
    geom_line(linewidth = 0.9) +
    scale_color_manual(values = group_colors) +
    coord_cartesian(ylim = c(0, 1)) +
    scale_x_continuous(breaks = x_breaks) +
    scale_y_continuous(breaks = seq(0, 1, by = 0.2),
                       labels = function(x) paste0(round(x * 100), "%")) +
    labs(x     = expression(bold("Round")),
         y     = expression(bold("Frac. of occupied slots")),
         title = bquote(bold(.(title)))) +
    mytheme
  if (!is.null(hline))
    p <- p + geom_hline(yintercept = hline, linetype = "dotted", color = "gray40")
  p
}

p_evo_byz <- make_evo_panel("sl_byz", "Slots: Byzantine only")
p_evo_hon <- make_evo_panel("sl_hon", "Slots: Honest only")
p_evo_mix <- make_evo_panel("sl_mix", "Slots: Mixed (byz + honest)")

# ── Rangee 2 : boxplots aux snapshots ─────────────────────────────────────────
d_snap <- d_raw[d_raw$time %in% snap_times, ]

time_labels <- sapply(snap_times, function(t) sprintf("%d", t))
names(time_labels) <- as.character(snap_times)
d_snap$time_f <- factor(d_snap$time,
  levels = snap_times,
  labels = time_labels[as.character(snap_times)])

whisker_lim <- function(x, margin = 0.08) {
  if (all(is.na(x))) return(c(0, 1))
  q   <- quantile(x, c(0.25, 0.75), na.rm = TRUE)
  iqr <- q[2] - q[1]
  lo  <- max(0, q[1] - 1.5 * iqr - iqr * margin)
  hi  <- min(1, q[2] + 1.5 * iqr + iqr * margin)
  c(lo, hi)
}

lim_byz <- whisker_lim(d_snap$sl_byz)
lim_hon <- whisker_lim(d_snap$sl_hon)
lim_mix <- whisker_lim(d_snap$sl_mix)

make_box_panel <- function(metric_col, title, ylims) {
  ggplot(d_snap, aes(x = time_f, y = .data[[metric_col]],
                     fill = group, color = group)) +
    pre_post_bg +
    geom_boxplot(outlier.size = 0.5, outlier.alpha = 0.4,
                 linewidth = 0.4, alpha = 0.75,
                 position = position_dodge(width = 0.8)) +
    stat_summary(fun = mean, geom = "point", shape = 18, size = 2,
                 position = position_dodge(width = 0.8),
                 show.legend = FALSE) +
    scale_fill_manual(values  = group_colors) +
    scale_color_manual(values = group_borders) +
    scale_y_continuous(labels = function(x) paste0(round(x * 100), "%")) +
    coord_cartesian(ylim = ylims) +
    labs(x     = expression(bold("Round")),
         y     = expression(bold("Frac. of occupied slots")),
         title = bquote(bold(.(title)))) +
    mytheme
}

p_box_byz <- make_box_panel("sl_byz", "Slots: Byzantine only", lim_byz)
p_box_hon <- make_box_panel("sl_hon", "Slots: Honest only",    lim_hon)
p_box_mix <- make_box_panel("sl_mix", "Slots: Mixed",          lim_mix)

# ── Legende commune (extraite d'un panel) ─────────────────────────────────────
panels_no_legend <- lapply(
  list(p_evo_byz, p_evo_hon, p_evo_mix, p_box_byz, p_box_hon, p_box_mix),
  function(p) p + theme(legend.position = "none"))

# ── Titre global ──────────────────────────────────────────────────────────────
t_pct      <- t_count / nodes * 100
main_title <- sprintf(
  "%s  |  N=%d  f=%d (%.0f%%)  x=%d (%.0f%%) trusted  budget=%.1f KB  attack@t=%d",
  toupper(strategy), nodes, faulty_count, faulty_pct,
  t_count, t_pct, budget, attack_start)

# ── Sauvegarde ────────────────────────────────────────────────────────────────
dir.create("results", showWarnings = FALSE)
outfile <- sprintf("results/slots_bytrust_%s_f%d_b%.1f_x%d.pdf",
  strategy, faulty_count, budget, t_count)

if (requireNamespace("cowplot", quietly = TRUE)) {
  library(cowplot)
  legend_grob <- get_legend(
    p_evo_byz + theme(legend.position  = "right",
                      legend.direction = "vertical",
                      legend.text      = element_text(size = 12, face = "bold")))
  row1  <- plot_grid(plotlist = panels_no_legend[1:3], nrow = 1, rel_widths = c(1, 1, 1))
  row2  <- plot_grid(plotlist = panels_no_legend[4:6], nrow = 1, rel_widths = c(1, 1, 1))
  rows  <- plot_grid(row1, row2, ncol = 1, rel_heights = c(1, 1))
  full  <- plot_grid(rows, legend_grob, nrow = 1, rel_widths = c(3, 0.25))
  title_p <- ggdraw() + draw_label(main_title, fontface = "bold", size = 10)
  final <- plot_grid(title_p, full, ncol = 1, rel_heights = c(0.05, 1))
  ggsave(outfile, final, width = 14, height = 8)
} else {
  row_label_evo <- grid::textGrob("--- Evolution ---",
                                   gp = grid::gpar(fontface = "bold", cex = 0.9))
  row_label_box <- grid::textGrob("--- Boxplots (snapshots) ---",
                                   gp = grid::gpar(fontface = "bold", cex = 0.9))
  title_grob    <- grid::textGrob(main_title,
                                   gp = grid::gpar(fontface = "bold", cex = 0.8))
  pdf(outfile, width = 14, height = 8)
  gridExtra::grid.arrange(
    grobs = c(list(title_grob, row_label_evo), panels_no_legend[1:3],
              list(row_label_box), panels_no_legend[4:6]),
    layout_matrix = rbind(c(1, 1, 1),
                          c(2, 2, 2),
                          c(3, 4, 5),
                          c(6, 6, 6),
                          c(7, 8, 9)),
    heights = c(0.08, 0.05, 1, 0.05, 1))
  dev.off()
}

cat("Sauvegarde dans:", outfile, "\n")
