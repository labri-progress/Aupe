#!/usr/bin/env Rscript
# Usage: Rscript plot_metrics_evolution_bytrust.r <budget> <faulty_pct> [strategy] [p_merge]
# Example: Rscript plot_metrics_evolution_bytrust.r 1 20
#          Rscript plot_metrics_evolution_bytrust.r 1 20 decay 10
#
# For each trusted_pct value, reads the per-node CSV file, keeps only Honest
# nodes, and computes their per-round mean for:
#   - Contamination ratio (avgByzN / view)
#   - DKL divergence (h_dkl)
#   - F1 score (h_f1)
#   - Bias factor error (h_biasErr)
#
# Each panel shows one line per trusted percentage
# (e.g. "BMDecay noMerge", "BMDecay t=5%", …)
#
# Output: results/metrics_evo_trust_strat<s>_f<f>_b<b>.pdf

args <- commandArgs(trailingOnly = TRUE)

library(ggplot2)
library(dplyr)
library(gridExtra)

# ── Parameters ────────────────────────────────────────────────────────────────
budget       <- as.numeric(args[1])
faulty_pct   <- as.integer(args[2])
strategy     <- if (length(args) >= 3) as.character(args[3]) else "decay"
round_to_stop <- if (length(args) >= 4) as.integer(args[4]) else 200
p_merge      <- if (length(args) >= 5) as.integer(args[5]) else 10

nodes        <- 1000
view         <- 20
faulty_count <- as.integer(nodes * faulty_pct / 100)
trusted_pcts   <- c(0, 5, 10, 20)
trusted_counts <- as.integer(nodes * trusted_pcts / 100)
results_dir  <- "results_merge"

# ── Style ─────────────────────────────────────────────────────────────────────
width  <- 10
height <- 4

custom_colors <- c("0"  = "#000000",
                   "5"  = "#E69F00",
                   "10" = "#56B4E9",
                   "20" = "#009E73",
                   "30" = "#D55E00")

mytheme <- theme(
  panel.grid.major = element_line(color = "gray90", linewidth=0.5),
  panel.grid.minor = element_line(color = "gray95", linewidth=0.25),
  panel.background = element_rect(fill = "white"),
  plot.background = element_rect(fill = "white"),
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

# ── Read and aggregate data ────────────────────────────────────────────────────
all_data <- data.frame()

for (ti in seq_along(trusted_pcts)) {
  t_pct   <- trusted_pcts[ti]
  t_count <- trusted_counts[ti]

  if (strategy == "array") {
    fname <- file.path(results_dir,
                       sprintf("nodes-%s-%d-%d-%d-%d-%d.csv",
                               strategy, nodes, view, faulty_count, t_count, p_merge))
  } else {
    fname <- file.path(results_dir,
                       sprintf("nodes-%s-%d-%d-%d-%d-%d-%d.csv",
                               strategy, nodes, view, faulty_count, t_count, p_merge, budget))
  }

  if (!file.exists(fname)) {
    cat("Warning: file not found:", fname, "\n"); next
  }
  cat("Reading:", fname, "\n")

  d <- read.table(fname, header = TRUE)
  d$time    <- as.integer(d$time)
  d <- d[d$time <= round_to_stop, ]
  d$node_id <- as.integer(d$node_id)

  # Keep only Honest nodes
  d <- d[d$node_id >= faulty_count + t_count, ]
  if (nrow(d) == 0) {
    cat("Warning: no honest nodes found in:", fname, "\n"); next
  }

  d$res     <- d$avgByzN / view
  d$dkl     <- d$h_dkl
  d$f1      <- d$h_f1
  d$biasErr <- d$h_biasErr
  d$occ     <- d$h_occ
  d$t_pct   <- t_pct

  all_data <- rbind(all_data, d[, c("time", "t_pct", "res", "dkl", "f1", "biasErr", "occ")])
}

if (nrow(all_data) == 0) {
  cat("No data found. Check results_dir and file naming.\n"); quit(status = 1)
}

# ── Per-round mean over honest nodes ──────────────────────────────────────────
avg_data <- all_data %>%
  group_by(t_pct, time) %>%
  summarise(res     = mean(res,     na.rm = TRUE),
            dkl     = mean(dkl,     na.rm = TRUE),
            f1      = mean(f1,      na.rm = TRUE),
            biasErr = mean(biasErr, na.rm = TRUE),
            occ     = mean(occ,     na.rm = TRUE),
            .groups = "drop")

# ── Labels ────────────────────────────────────────────────────────────────────
strat_name <- switch(strategy, "bm" = "BM", "decay" = "BMDecay", strategy)
avg_data$label <- ifelse(
  avg_data$t_pct == 0,
  paste0(strat_name, " noMerge"),
  paste0(strat_name, " t=", avg_data$t_pct, "%")
)
avg_data$label_f <- factor(avg_data$label, levels = unique(avg_data$label))

label_color_map <- avg_data %>%
  distinct(label_f, t_pct) %>%
  mutate(color = custom_colors[as.character(t_pct)])
label_colors <- setNames(label_color_map$color, label_color_map$label_f)

# ── X-axis breaks ─────────────────────────────────────────────────────────────
max_time <- max(avg_data$time)
if (max_time > 200) {
  x_breaks <- seq(0, max_time, by = 200)
} else if (max_time > 50) {
  x_breaks <- seq(0, max_time, by = 50)
} else {
  x_breaks <- sort(unique(avg_data$time))
}

optimal <- faulty_pct / 100

# ── Panel 1: contamination ratio ──────────────────────────────────────────────
p_cr <- ggplot(avg_data, aes(x = time, y = res, color = label_f, group = label_f)) +
  geom_hline(yintercept = optimal, linetype = "dashed", color = "gray50") +
  geom_line(linewidth = 0.8) +
  scale_color_manual(values = label_colors) +
  coord_cartesian(ylim = c(0, 1)) +
  scale_x_continuous(breaks = x_breaks) +
  scale_y_continuous(breaks = seq(0, 1, by = 0.2)) +
  labs(x = expression(bold("Rounds")),
       y = expression(bold("Prop. of Byz. samples"))) +
  mytheme +
  theme(legend.position = c(0.55, 0.40)) +
    guides(color = guide_legend(title = NULL, ncol = 2))

# ── Panel 2: DKL divergence ────────────────────────────────────────────────────
p_dkl <- ggplot(avg_data, aes(x = time, y = dkl, color = label_f, group = label_f)) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "gray50") +
  geom_line(linewidth = 0.8) +
  scale_color_manual(values = label_colors) +
  scale_x_continuous(breaks = x_breaks) +
  labs(x = expression(bold("Rounds")),
       y = expression(bold("DKL"))) +
  mytheme +
  theme(legend.position = "none")

# ── Panel 3: F1 score ──────────────────────────────────────────────────────────
p_f1 <- ggplot(avg_data, aes(x = time, y = f1, color = label_f, group = label_f)) +
  geom_line(linewidth = 0.8) +
  scale_color_manual(values = label_colors) +
  coord_cartesian(ylim = c(0, 1)) +
  scale_x_continuous(breaks = x_breaks) +
  scale_y_continuous(breaks = seq(0, 1, by = 0.2)) +
  labs(x = expression(bold("Rounds")),
       y = expression(bold("F1"))) +
  mytheme +
  theme(legend.position = "none")

# ── Panel 4: Bias factor error ─────────────────────────────────────────────────
p_bias <- ggplot(avg_data, aes(x = time, y = biasErr, color = label_f, group = label_f)) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "gray50") +
  geom_line(linewidth = 0.8) +
  scale_color_manual(values = label_colors) +
  scale_x_continuous(breaks = x_breaks) +
  labs(x = expression(bold("Rounds")),
       y = expression(bold("Bias factor err."))) +
  mytheme +
  theme(legend.position = "none")

# ── Panel 5: Occupancy ────────────────────────────────────────────────────────
p_occ <- ggplot(avg_data, aes(x = time, y = occ, color = label_f, group = label_f)) +
  geom_line(linewidth = 0.8) +
  scale_color_manual(values = label_colors) +
  scale_x_continuous(breaks = x_breaks) +
  scale_y_continuous(breaks = seq(0, 1, by = 0.2)) +
  labs(x = expression(bold("Rounds")),
       y = expression(bold("Occupancy"))) +
  mytheme +
  theme(legend.position = "none")

# ── Save PDF ──────────────────────────────────────────────────────────────────
dir.create("results", showWarnings = FALSE)
outfile <- sprintf("results/metrics_evo_trust_strat%s_f%d_b%s.pdf", strategy, faulty_pct, budget)
pdf(outfile, width = width * 5/4, height = height)
grid.arrange(p_cr, p_f1, p_bias, p_occ, nrow = 1, ncol = 4)#p_f1,p_dkl
dev.off()
cat("Saved to:", outfile, "\n")
