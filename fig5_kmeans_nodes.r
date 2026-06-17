#!/usr/bin/env Rscript
# Usage: Rscript fig5_kmeans_nodes.r <strategy> <faulty_pct> [budget] [t_count] [p_merge] [round_from] [round_to]
#
# Classification KMeans (k=2) des noeuds corrects en Trusted vs Honnêtes à
# partir de leur proportion moyenne de byzantins dans la vue (avgByzN / view)
# sur une fenêtre de rounds post-attaque.
#
# Classification de référence (Rust) :
#   node_id ∈ [0,       F-1]      → Byzantins  (exclus de l'analyse)
#   node_id ∈ [F,    F+T-1]       → Nœuds de confiance (Trusted)
#   node_id ∈ [F+T,  N-1]         → Nœuds corrects ordinaires (Honnêtes)
#
# Le cluster KMeans dont la moyenne est la plus faible est associé à "Trusted"
# (les nœuds de confiance ont des vues moins biaisées).
#
# Métriques calculées : Precision, Recall, F1-score (classe positive = Trusted)
#
# Sortie : résultats texte + PDF avec (1) densités + frontière KMeans,
#          (2) heatmap de la matrice de confusion.
#
# Nom du fichier nodes attendu dans output_byz :
#   decay2 : nodes-decay2-{N}-{v}-{F}-{T}-{p_merge}-{budget}.csv
#   array  : nodes-array-{N}-{v}-{F}-{T}-{run}.csv
#   Autre  : chemin libre — passer le chemin absolu comme <strategy>

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2) {
  cat("Usage: Rscript fig5_kmeans_nodes.r <strategy> <faulty_pct>",
      "[budget] [t_count] [p_merge] [round_from] [round_to]\n")
  quit(status = 1)
}

library(ggplot2)
library(dplyr)
library(gridExtra)

# ── Paramètres ────────────────────────────────────────────────────────────────
strategy   <- as.character(args[1])
faulty_pct <- as.integer(args[2])
budget     <- if (length(args) >= 3) as.numeric(args[3]) else 0.5
t_count    <- if (length(args) >= 4) as.integer(args[4]) else 100
p_merge    <- if (length(args) >= 5) as.integer(args[5]) else 1
round_from <- if (length(args) >= 6) as.integer(args[6]) else 11000L
round_to   <- if (length(args) >= 7) as.integer(args[7]) else 11049L

nodes       <- 1000
view        <- 20
faulty_count <- as.integer(nodes * faulty_pct / 100)
results_dir <- "output_byz"

cat(sprintf("Paramètres : strategy=%s  f=%d (%d%%)  t=%d  rounds [%d,%d]\n",
            strategy, faulty_count, faulty_pct, t_count, round_from, round_to))

# ── Résolution du chemin vers le fichier nodes ────────────────────────────────
resolve_path <- function() {
  # Cas 1 : l'utilisateur a fourni directement un chemin de fichier existant
  if (file.exists(strategy)) return(strategy)
  # Cas 2 : decay2 → format avec budget
  if (strategy == "decay2") {
    p <- file.path(results_dir,
      sprintf("nodes-%s-%d-%d-%d-%d-%d-%.1f.csv",
              strategy, nodes, view, faulty_count, t_count, p_merge, budget))
    if (file.exists(p)) return(p)
    # Essai sans p_merge dans le nom
    p2 <- file.path(results_dir,
      sprintf("nodes-%s-%d-%d-%d-%d-%.1f.csv",
              strategy, nodes, view, faulty_count, t_count, budget))
    if (file.exists(p2)) return(p2)
  }
  # Cas 3 : array ou autre stratégie sans budget — p_merge joue le rôle de run
  p <- file.path(results_dir,
    sprintf("nodes-%s-%d-%d-%d-%d-%d.csv",
            strategy, nodes, view, faulty_count, t_count, p_merge))
  if (file.exists(p)) return(p)
  # Cas 4 : fallback avec juste t_count et p_merge
  p <- file.path(results_dir,
    sprintf("nodes-%s-%d-%d-%d-%d.csv",
            strategy, nodes, view, faulty_count, t_count))
  if (file.exists(p)) return(p)
  # Pas trouvé : lister les candidats
  cat("Fichier nodes introuvable. Candidats dans", results_dir, ":\n")
  cat(paste(list.files(results_dir, pattern = "^nodes-"), collapse = "\n"), "\n")
  return(NULL)
}

fname <- resolve_path()
if (is.null(fname)) quit(status = 1)
cat("Lecture :", fname, "\n")

# ── Lecture ───────────────────────────────────────────────────────────────────
d <- read.table(fname, header = TRUE)
d$time    <- as.integer(d$time)
d$node_id <- as.integer(d$node_id)

# Fenêtre de rounds
d_win <- d[d$time >= round_from & d$time <= round_to, ]
n_rounds_found <- length(unique(d_win$time))

if (n_rounds_found == 0) {
  cat(sprintf("Aucun round trouvé dans [%d, %d]. Rounds disponibles : %s\n",
              round_from, round_to,
              paste(sort(unique(d$time)), collapse = ", ")))
  quit(status = 1)
}
if (n_rounds_found < (round_to - round_from + 1)) {
  cat(sprintf("Attention : %d round(s) trouvé(s) sur %d attendus dans [%d, %d].\n",
              n_rounds_found, round_to - round_from + 1, round_from, round_to))
}

# ── Exclusion des byzantins et étiquetage (classes vraies) ────────────────────
# Les byzantins (node_id < faulty_count) ne doivent pas apparaître dans le
# fichier nodes, mais on les filtre par précaution.
d_win <- d_win[d_win$node_id >= faulty_count, ]

d_win$true_class <- ifelse(
  d_win$node_id < faulty_count + t_count,
  "Trusted",
  "Honnete"
)

# ── Feature : proportion moyenne de byzantins sur la fenêtre ──────────────────
node_feat <- d_win %>%
  group_by(node_id, true_class) %>%
  summarise(mean_propByz = mean(avgByzN / view, na.rm = TRUE), .groups = "drop")

n_trusted <- sum(node_feat$true_class == "Trusted")
n_honest  <- sum(node_feat$true_class == "Honnete")
cat(sprintf("Nœuds : %d Trusted / %d Honnêtes\n", n_trusted, n_honest))

if (n_trusted == 0) {
  cat("Aucun nœud Trusted (t_count = 0 ou absent du fichier). KMeans non possible.\n")
  quit(status = 1)
}

# ── KMeans k = 2 ──────────────────────────────────────────────────────────────
set.seed(42)
km <- kmeans(node_feat$mean_propByz, centers = 2, nstart = 25)

# Le cluster avec la moyenne la plus faible correspond aux Trusted
cluster_means <- tapply(node_feat$mean_propByz, km$cluster, mean)
trusted_cluster  <- as.integer(names(which.min(cluster_means)))
honnete_cluster  <- as.integer(names(which.max(cluster_means)))

node_feat$pred_class <- ifelse(km$cluster == trusted_cluster, "Trusted", "Honnete")
boundary_val         <- mean(km$centers)   # frontière de décision approximative

cat(sprintf("Centres KMeans : cluster Trusted = %.4f / cluster Honnête = %.4f\n",
            cluster_means[trusted_cluster], cluster_means[honnete_cluster]))
cat(sprintf("Frontière de décision ~ %.4f\n", boundary_val))

# ── Métriques de classification ───────────────────────────────────────────────
TP <- sum(node_feat$true_class == "Trusted"  & node_feat$pred_class == "Trusted")
FP <- sum(node_feat$true_class == "Honnete"  & node_feat$pred_class == "Trusted")
FN <- sum(node_feat$true_class == "Trusted"  & node_feat$pred_class == "Honnete")
TN <- sum(node_feat$true_class == "Honnete"  & node_feat$pred_class == "Honnete")

precision <- if ((TP + FP) > 0) TP / (TP + FP) else NA_real_
recall    <- if ((TP + FN) > 0) TP / (TP + FN) else NA_real_
f1        <- if (!is.na(precision) && !is.na(recall) && (precision + recall) > 0)
               2 * precision * recall / (precision + recall) else NA_real_

cat("\n── Métriques de classification ──────────────────────────────────────\n")
cat(sprintf("  TP = %d  FP = %d  FN = %d  TN = %d\n", TP, FP, FN, TN))
cat(sprintf("  Precision = %.4f\n  Recall    = %.4f\n  F1-score  = %.4f\n",
            precision, recall, f1))
cat("────────────────────────────────────────────────────────────────────\n\n")

# ── Thème ─────────────────────────────────────────────────────────────────────
mytheme <- theme(
  panel.grid.major      = element_line(color = "gray90", linewidth = 0.5),
  panel.grid.minor      = element_line(color = "gray95", linewidth = 0.25),
  panel.background      = element_rect(fill = "white"),
  plot.background       = element_rect(fill = "white"),
  panel.border          = element_rect(colour = "black", linewidth = 1, fill = NA),
  text                  = element_text(size = 12, color = "black"),
  axis.title.x          = element_text(size = 12, face = "bold"),
  axis.title.y          = element_text(size = 12, face = "bold"),
  axis.text.x           = element_text(size = 11, face = "bold"),
  axis.text.y           = element_text(size = 11, face = "bold"),
  plot.title            = element_text(size = 12, face = "bold"),
  legend.text           = element_text(size = 11, face = "bold"),
  legend.title          = element_text(size = 11, face = "bold"),
  legend.background     = element_rect(fill = "transparent", colour = NA),
  legend.box.background = element_rect(fill = "transparent", colour = NA),
  axis.ticks            = element_line(color = "black", linewidth = 1)
)

class_colors <- c("Trusted" = "#56B4E9", "Honnete" = "#E69F00")

# ── Panneau 1 : densités et frontière KMeans ──────────────────────────────────
p_density <- ggplot(node_feat, aes(x = mean_propByz, fill = true_class, color = true_class)) +
  geom_density(alpha = 0.35, linewidth = 0.7) +
  geom_vline(xintercept = boundary_val, linetype = "dashed",
             color = "black", linewidth = 0.8) +
  annotate("text", x = boundary_val, y = Inf, label = "KMeans\nboundary",
           vjust = 1.5, hjust = -0.1, size = 3.5, fontface = "bold") +
  scale_fill_manual(values  = class_colors) +
  scale_color_manual(values = class_colors) +
  scale_x_continuous(
    labels = function(x) paste0(round(x * 100, 1), "%"),
    breaks = pretty(node_feat$mean_propByz, n = 8)
  ) +
  labs(
    title = sprintf("Distribution de la proportion byz. moyenne par nœud [rounds %d–%d]",
                    round_from, round_to),
    x     = expression(bold("Proportion moyenne de byz. dans la vue")),
    y     = expression(bold("Densité")),
    fill  = "Classe vraie",
    color = "Classe vraie"
  ) +
  mytheme +
  theme(legend.position = c(0.85, 0.80))

# ── Panneau 2 : matrice de confusion (heatmap) ────────────────────────────────
cm_df <- data.frame(
  true_class = factor(c("Trusted", "Trusted", "Honnete", "Honnete"),
                      levels = c("Trusted", "Honnete")),
  pred_class = factor(c("Trusted", "Honnete", "Trusted", "Honnete"),
                      levels = c("Trusted", "Honnete")),
  count      = c(TP, FN, FP, TN)
)

p_cm <- ggplot(cm_df, aes(x = pred_class, y = true_class, fill = count)) +
  geom_tile(color = "white", linewidth = 1.2) +
  geom_text(aes(label = count), size = 7, fontface = "bold", color = "white") +
  scale_fill_gradient(low = "#d9ecff", high = "#005aaa") +
  scale_x_discrete(position = "bottom") +
  labs(
    title = sprintf("Matrice de confusion\nP=%.3f  R=%.3f  F1=%.3f",
                    precision, recall, f1),
    x     = expression(bold("Classe prédite (KMeans)")),
    y     = expression(bold("Classe vraie")),
    fill  = "Effectif"
  ) +
  mytheme +
  theme(
    legend.position = "right",
    axis.ticks      = element_blank(),
    panel.border    = element_rect(colour = "black", linewidth = 1, fill = NA)
  )

# ── Sauvegarde ────────────────────────────────────────────────────────────────
dir.create("results", showWarnings = FALSE)
outfile <- sprintf("results/fig5_kmeans_%s_f%d_t%d_%d-%d.pdf",
                   strategy, faulty_count, t_count, round_from, round_to)

pdf(outfile, width = 12, height = 5)
grid.arrange(p_density, p_cm, nrow = 1, ncol = 2, widths = c(1.6, 1))
dev.off()
cat("Sauvegarde dans:", outfile, "\n")
