#!/usr/bin/env Rscript
# Usage: Rscript fig5_kmeans_nodes.r <budget> [p_merge] [round_from] [round_to]
#
# Classification KMeans (k=2) des nœuds corrects (Trusted vs Honnêtes) pour la
# stratégie decay2, sur toutes les combinaisons de :
#   faulty_pcts  = 10, 20, 30, 40 %
#   trusted_pcts = 5, 10, 20 %
#
# Feature par nœud : proportion moyenne de byzantins dans la vue (avgByzN/view)
# sur la fenêtre de rounds [round_from, round_to].
#
# Classification de référence (Rust) :
#   node_id ∈ [0,    F-1]    → Byzantins (exclus de l'analyse)
#   node_id ∈ [F,  F+T-1]   → Nœuds de confiance (Trusted)   ← classe positive
#   node_id ∈ [F+T, N-1]    → Nœuds corrects ordinaires (Honnêtes)
#
# Le cluster KMeans à la plus faible moyenne → Trusted.
#
# Figure 3 panneaux côte à côte :
#   X = valeur de la métrique (0 à 1)
#   Y = proportion de byzantins dans le système (faulty %)
#   Courbes = t = 5 %, t = 10 %, t = 20 %
#
# Fichiers nodes attendus dans output_byz :
#   nodes-decay2-{N}-{v}-{F}-{T}-{p_merge}-{budget}.csv

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1) {
  cat("Usage: Rscript fig5_kmeans_nodes.r <budget> [p_merge] [round_from] [round_to]\n")
  quit(status = 1)
}

library(ggplot2)
library(dplyr)
library(tidyr)
library(gridExtra)

# ── Paramètres ────────────────────────────────────────────────────────────────
budget       <- as.numeric(args[1])
p_merge      <- if (length(args) >= 2) as.integer(args[2]) else 1L
round_from   <- if (length(args) >= 3) as.integer(args[3]) else 11000L
round_to     <- if (length(args) >= 4) as.integer(args[4]) else 11049L

strategy     <- "decay2"
nodes        <- 1000
view         <- 20
faulty_pcts  <- c(10, 20, 30, 40)
trusted_pcts <- c(5, 10, 20, 30)
results_dir  <- "output_byz"

cat(sprintf("Budget=%.1f  p_merge=%d  rounds [%d, %d]\n",
            budget, p_merge, round_from, round_to))

# ── KMeans sur un fichier nodes ───────────────────────────────────────────────
classify_file <- function(fname, faulty_count, t_count) {
  if (!file.exists(fname)) {
    cat("Warning: fichier absent:", fname, "\n")
    return(NULL)
  }
  d <- read.table(fname, header = TRUE)
  d$time    <- as.integer(d$time)
  d$node_id <- as.integer(d$node_id)

  # Fenêtre post-attaque
  d_win <- d[d$time >= round_from & d$time <= round_to, ]
  n_found <- length(unique(d_win$time))
  if (n_found == 0) {
    cat(sprintf("Warning: aucun round dans [%d,%d] dans %s\n", round_from, round_to, fname))
    return(NULL)
  }
  if (n_found < (round_to - round_from + 1)) {
    cat(sprintf("Info: %d round(s) sur %d attendus dans [%d,%d] (%s)\n",
                n_found, round_to - round_from + 1, round_from, round_to,
                basename(fname)))
  }

  # Exclure les byzantins par précaution (ne devraient pas être dans le fichier)
  d_win <- d_win[d_win$node_id >= faulty_count, ]

  # Étiquettes vraies
  d_win$true_class <- ifelse(
    d_win$node_id < faulty_count + t_count, "Trusted", "Honnete"
  )

  # Feature : propByz moyenne sur la fenêtre
  node_feat <- d_win %>%
    group_by(node_id, true_class) %>%
    summarise(mean_propByz = mean(avgByzN / view, na.rm = TRUE), .groups = "drop")

  n_trusted <- sum(node_feat$true_class == "Trusted")
  if (n_trusted == 0) {
    cat("Warning: aucun nœud Trusted dans", basename(fname), "\n")
    return(NULL)
  }

  # KMeans k=2
  set.seed(42)
  km <- kmeans(node_feat$mean_propByz, centers = 2, nstart = 25)

  # Cluster avec la moyenne la plus faible → Trusted
  cluster_means   <- tapply(node_feat$mean_propByz, km$cluster, mean)
  trusted_cluster <- as.integer(names(which.min(cluster_means)))

  node_feat$pred_class <- ifelse(km$cluster == trusted_cluster, "Trusted", "Honnete")

  # Métriques (classe positive = Trusted)
  TP <- sum(node_feat$true_class == "Trusted"  & node_feat$pred_class == "Trusted")
  FP <- sum(node_feat$true_class == "Honnete"  & node_feat$pred_class == "Trusted")
  FN <- sum(node_feat$true_class == "Trusted"  & node_feat$pred_class == "Honnete")
  TN <- sum(node_feat$true_class == "Honnete"  & node_feat$pred_class == "Honnete")

  precision <- if ((TP + FP) > 0) TP / (TP + FP) else NA_real_
  recall    <- if ((TP + FN) > 0) TP / (TP + FN) else NA_real_
  f1        <- if (!is.na(precision) && !is.na(recall) && (precision + recall) > 0)
                 2 * precision * recall / (precision + recall) else NA_real_

  cat(sprintf("  f=%d%% t=%d%% → P=%.3f R=%.3f F1=%.3f  (TP=%d FP=%d FN=%d TN=%d)\n",
              round(faulty_count / nodes * 100),
              round(t_count      / nodes * 100),
              precision, recall, f1, TP, FP, FN, TN))

  data.frame(precision = precision, recall = recall, f1 = f1)
}

# ── Chargement de toutes les combinaisons ─────────────────────────────────────
rows <- list()
for (f_pct in faulty_pcts) {
  f <- as.integer(nodes * f_pct / 100)
  for (t_pct in trusted_pcts) {
    t <- as.integer(nodes * t_pct / 100)
    fname <- file.path(results_dir,
      sprintf("nodes-%s-%d-%d-%d-%d-%d-%.1f.csv",
              strategy, nodes, view, f, t, p_merge, budget))
    m <- classify_file(fname, f, t)
    if (!is.null(m)) {
      rows[[length(rows) + 1]] <- data.frame(
        f_pct    = f_pct,
        t_label  = paste0("t = ", t_pct, "%"),
        precision = m$precision,
        recall    = m$recall,
        f1        = m$f1
      )
    }
  }
}

if (length(rows) == 0) {
  cat("Aucune donnée valide. Vérifiez les fichiers nodes-decay2-* dans", results_dir, "\n")
  quit(status = 1)
}

df_all <- do.call(rbind, rows)

# ── Mise en forme longue ───────────────────────────────────────────────────────
df_long <- df_all %>%
  pivot_longer(cols = c(precision, recall, f1),
               names_to  = "metric",
               values_to = "value") %>%
  mutate(
    metric  = factor(metric,
                     levels = c("precision", "recall", "f1"),
                     labels = c("Precision", "Recall", "F1-score")),
    t_label = factor(t_label, levels = paste0("t = ", trusted_pcts, "%")),
    f_pct   = as.numeric(as.character(f_pct)) / 100
  )

# ── Thème ─────────────────────────────────────────────────────────────────────
mytheme <- theme(
  panel.grid.major        = element_line(color = "gray90",  linewidth = 0.50),
  panel.grid.minor        = element_line(color = "gray95",  linewidth = 0.25),
  panel.background        = element_rect(fill = "white"),
  plot.background         = element_rect(fill = "white"),
  panel.border            = element_rect(colour = "black", linewidth = 1, fill = NA),
  text                    = element_text(size = 9, color = "black"),
  axis.title.x            = element_text(size = 9, face = "bold"),
  axis.title.y            = element_text(size = 9, face = "bold"),
  axis.text.x             = element_text(size = 8, face = "bold"),
  axis.text.y             = element_text(size = 8, face = "bold"),
  plot.title              = element_text(size = 9, face = "bold"),
  legend.text             = element_text(size = 8, face = "bold"),
  legend.title            = element_blank(),
  legend.background       = element_rect(fill = "transparent", colour = NA),
  legend.box.background   = element_rect(fill = "transparent", colour = NA),
  #legend.key.spacing.y = unit(-2, "pt"),   # rapproche les items
  legend.key.height    = unit(9,  "pt"),   # réduit la hauteur de chaque item
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

# ── Palette cohérente avec les autres scripts ─────────────────────────────────
t_colors <- c(
  "t = 5%"  = "#E69F00",   # orange
  "t = 10%" = "#56B4E9",   # bleu ciel
  "t = 20%" = "#009E73",   # vert
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

# ── Construction d'un panneau ─────────────────────────────────────────────────
make_panel <- function(metric_name, show_legend = FALSE, show_y_title = TRUE) {
  sub <- df_long %>% filter(metric == metric_name)
  ggplot(sub, aes(x = f_pct, y = value,
                  color = t_label, shape = t_label, linetype = t_label,
                  group = t_label)) +
    geom_line(linewidth  = 0.5) +
    geom_point(size = 1.5) +
    scale_color_manual(values = t_colors, drop = FALSE) +
    scale_shape_manual(values = t_shapes, drop = FALSE) +
    scale_linetype_manual(values = t_lty,  drop = FALSE) +
    scale_x_continuous(
      breaks       = faulty_pcts / 100,
      minor_breaks = NULL,
      sec.axis     = dup_axis(labels = NULL, name = NULL)
    ) +
    scale_y_continuous(
      limits       = c(0, 1),
      breaks       = seq(0, 1, by = 0.2),
      minor_breaks = seq(0, 1, by = 0.1),
      sec.axis     = dup_axis(labels = NULL, name = NULL)
    ) +
    labs(
      x     = expression(bold("Prop. of Byz. nodes")),
      y     = if (show_y_title) expression(bold("Metric value")) else NULL,
      title = metric_name
    ) +
    mytheme +
    theme(legend.position = if (show_legend) c(0.5, 0.85) else "none") +
    guides(color    = guide_legend(ncol = 2),
           shape    = guide_legend(ncol = 2),
           linetype = guide_legend(ncol = 1))
}

# ── Grille 1×3 ────────────────────────────────────────────────────────────────
p_prec   <- make_panel("Precision", show_legend = TRUE,  show_y_title = TRUE)
p_recall <- make_panel("Recall",    show_legend = FALSE, show_y_title = FALSE)
p_f1     <- make_panel("F1-score",  show_legend = FALSE, show_y_title = FALSE)

dir.create("results", showWarnings = FALSE)
outfile <- sprintf("results/fig5_kmeans_decay2_%d-%d_%gKB.pdf",
                   round_from, round_to, budget)
pdf(outfile, width = 7, height = 2)
grid.arrange(p_prec, p_recall, p_f1, nrow = 1, ncol = 3)
dev.off()
cat("Sauvegarde dans:", outfile, "\n")
