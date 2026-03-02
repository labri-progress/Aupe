#!/usr/bin/env Rscript
# Usage: Rscript plot_metrics_evolution.r <budget> <faulty_pct> [t_pct] [p_merge]
# Example: Rscript plot_metrics_evolution.r 1 10
#          Rscript plot_metrics_evolution.r 1 10 10 10   (with 10% trusted, p_merge=10)
#
# Plots boxplots of per-node metric distributions over time for the BMDecay strategy:
#   - Contamination ratio (Honest / Trusted)
#   - DKL divergence (Honest / Trusted)
#   - F1 score (Honest / Trusted)
#   - Bias factor error (Honest / Trusted)
#
# Data is read from results_merge/ with format:
#   nodes-decay-{nodes}-{view}-{faulty_count}-{t_count}-{p_merge}-{budget}.csv
#
# Output: results/metrics_boxplot_f<faulty_pct>_t<t_pct>_b<budget>.pdf

args <- commandArgs(trailingOnly = TRUE)

library(ggplot2)
library(dplyr)
library(gridExtra)

# ── Parameters ────────────────────────────────────────────────────────────────
budget       <- as.integer(args[1])                               # e.g. 1
faulty_pct   <- as.integer(args[2])                               # e.g. 10, 20, 30
t_pct        <- if (length(args) >= 3) as.integer(args[3]) else 0 # % trusted
p_merge      <- if (length(args) >= 4) as.integer(args[4]) else 10

nodes        <- 1000
view         <- 20
faulty_count <- as.integer(nodes * faulty_pct / 100)
t_count      <- as.integer(nodes * t_pct / 100)
strategy     <- if (length(args) >= 5) as.character(args[5]) else "decay"
results_dir  <- "results_merge"

if (strategy == "array") {
  fname <- file.path(results_dir,
                   sprintf("nodes-%s-%d-%d-%d-%d-%d.csv",
                           strategy, nodes, view, faulty_count, t_count, p_merge))
} else {
  fname <- file.path(results_dir,
                   sprintf("nodes-%s-%d-%d-%d-%d-%d-%d.csv",
                           strategy, nodes, view, faulty_count, t_count, p_merge, budget))
}

cat("Reading:", fname, "\n")
if (!file.exists(fname)) {
  cat("File not found:", fname, "\n"); quit(status = 1)
}

# ── Style ─────────────────────────────────────────────────────────────────────
width  <- 11
height <- 3.5

ht_colors <- c("Honest" = "#E69F00", "Trusted" = "#56B4E9")

mytheme <- theme(
  panel.grid.major      = element_blank(),
  panel.grid.minor      = element_blank(),
  panel.background      = element_rect(fill = "white"),
  plot.background       = element_rect(fill = "white"),
  panel.border          = element_rect(colour = "black", linewidth = 1, fill = NA),
  legend.spacing.y      = unit(0.005, "cm"),
  text                  = element_text(size = 12, color = "black"),
  axis.title.x          = element_text(size = 12, face = "bold"),
  axis.title.y          = element_text(size = 12, face = "bold"),
  axis.text.x           = element_text(size = 9,  face = "bold", angle = 45, hjust = 1),
  axis.text.y           = element_text(size = 11, face = "bold"),
  plot.title            = element_text(size = 12, face = "bold"),
  legend.text           = element_text(size = 11, face = "bold"),
  legend.title          = element_blank(),
  legend.background     = element_rect(fill = "transparent", colour = NA),
  legend.box.background = element_rect(fill = "transparent", colour = NA),
  axis.ticks            = element_line(color = "black", linewidth = 1)
)

# ── Read and prepare data ──────────────────────────────────────────────────────
d <- read.table(fname, header = TRUE)
d$time    <- as.integer(d$time)
d$node_id <- as.integer(d$node_id)

# Classify nodes by ID (byzantine nodes are already filtered out of the file)
d$group <- ifelse(d$node_id >= faulty_count + t_count, "Honest", "Trusted")
d$group <- factor(d$group, levels = c("Honest", "Trusted"))

# Per-node metric values: pick h_* for Honest, t_* for Trusted
d$res <- d$avgByzN / view
d$dkl       <- ifelse(d$group == "Honest", d$h_dkl,     d$t_dkl)
d$f1        <- ifelse(d$group == "Honest", d$h_f1,      d$t_f1)
d$biasErr   <- ifelse(d$group == "Honest", d$h_biasErr, d$t_biasErr)

# Subsample time steps to ~20 boxes for readability
n_boxes       <- 20
max_time      <- max(d$time)
step_interval <- max(1, floor(max_time / n_boxes))
plot_times    <- seq(0, max_time, by = step_interval)
pd            <- d[d$time %in% plot_times, ]
pd$time_f     <- factor(pd$time)

# Global mean of avgByzN/view across all nodes (Honest + Trusted) per time step
pd_all_mean <- pd %>%
  group_by(time_f) %>%
  summarise(mean_res = mean(res), .groups = "drop")

optimal <- faulty_pct / 100

# ── Panel 1: contamination ratio ──────────────────────────────────────────────
p_cr <- ggplot(pd, aes(x = time_f, y = res, color = group, fill = group)) +
  geom_hline(yintercept = optimal, linetype = "dashed", color = "gray50") +
  geom_boxplot(alpha = 0.3, outlier.size = 0.5, linewidth = 0.5, position = "dodge") +
  stat_summary(fun = mean, geom = "point", shape = 18, size = 2,
               position = position_dodge(0.9)) +
  geom_line(data = pd_all_mean, aes(x = time_f, y = mean_res, group = 1),
            color = "black", linewidth = 0.8, inherit.aes = FALSE,
            show.legend = FALSE) +
  scale_color_manual(values = ht_colors) +
  scale_fill_manual(values  = ht_colors) +
  coord_cartesian(ylim = c(0, 1)) +
  scale_y_continuous(breaks = seq(0, 1, by = 0.2)) +
  labs(x = expression(bold("Time steps")),
       y = expression(bold("Prop. of Byz. samples"))) +
  mytheme +
  theme(legend.position = c(0.72, 0.85))

# ── Panel 2: DKL divergence ────────────────────────────────────────────────────
p_dkl <- ggplot(pd, aes(x = time_f, y = dkl, color = group, fill = group)) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "gray50") +
  geom_boxplot(alpha = 0.3, outlier.size = 0.5, linewidth = 0.5, position = "dodge") +
  stat_summary(fun = mean, geom = "point", shape = 18, size = 2,
               position = position_dodge(0.9)) +
  scale_color_manual(values = ht_colors) +
  scale_fill_manual(values  = ht_colors) +
  labs(x = expression(bold("Time steps")),
       y = expression(bold("DKL"))) +
  mytheme +
  theme(legend.position = "none")

# ── Panel 3: F1 score ──────────────────────────────────────────────────────────
p_f1 <- ggplot(pd, aes(x = time_f, y = f1, color = group, fill = group)) +
  geom_boxplot(alpha = 0.3, outlier.size = 0.5, linewidth = 0.5, position = "dodge") +
  stat_summary(fun = mean, geom = "point", shape = 18, size = 2,
               position = position_dodge(0.9)) +
  scale_color_manual(values = ht_colors) +
  scale_fill_manual(values  = ht_colors) +
  coord_cartesian(ylim = c(0, 1)) +
  scale_y_continuous(breaks = seq(0, 1, by = 0.2)) +
  labs(x = expression(bold("Time steps")),
       y = expression(bold("F1"))) +
  mytheme +
  theme(legend.position = c(0.72, 0.20))

# ── Panel 4: Bias factor error ─────────────────────────────────────────────────
p_bias <- ggplot(pd, aes(x = time_f, y = biasErr, color = group, fill = group)) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "gray50") +
  geom_boxplot(alpha = 0.3, outlier.size = 0.5, linewidth = 0.5, position = "dodge") +
  stat_summary(fun = mean, geom = "point", shape = 18, size = 2,
               position = position_dodge(0.9)) +
  scale_color_manual(values = ht_colors) +
  scale_fill_manual(values  = ht_colors) +
  labs(x = expression(bold("Time steps")),
       y = expression(bold("Bias factor err."))) +
  mytheme +
  theme(legend.position = "none")

# ── Save PDF ──────────────────────────────────────────────────────────────────
dir.create("results", showWarnings = FALSE)
outfile <- sprintf("results/metrics_boxplot_strat%sf%d_t%d_b%d.pdf", strategy, faulty_pct, t_pct, budget)
pdf(outfile, width = width * 4/3, height = height)
grid.arrange(p_cr, p_dkl, p_f1, p_bias, nrow = 1, ncol = 4)
dev.off()
cat("Saved to:", outfile, "\n")
