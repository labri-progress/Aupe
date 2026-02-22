#!/usr/bin/env Rscript
# Usage: Rscript plot_metrics_evolution.r <budget> <faulty_pct> [t_pct] [p_merge]
# Example: Rscript plot_metrics_evolution.r 1 10
#          Rscript plot_metrics_evolution.r 1 10 10 10   (with 10% trusted, p_merge=10)
#
# Plots the temporal evolution of metrics for the BMDecay strategy:
#   - Contamination ratio split by group (Global / Honest / Trusted)
#   - DKL divergence (Honest and Trusted)
#   - F1 score (Honest and Trusted)
#
# Data is read from results_merge/ with format:
#   decay-{nodes}-{view}-{faulty_count}-{t_count}-{p_merge}-{budget}-run{run}
#
# Output: results/metrics_evolution_f<faulty_pct>_t<t_pct>_b<budget>.pdf

args <- commandArgs(trailingOnly = TRUE)

library(ggplot2)
library(dplyr)
library(gridExtra)

# ── Parameters ────────────────────────────────────────────────────────────────
budget       <- as.integer(args[1])                               # e.g. 1
faulty_pct   <- as.integer(args[2])                               # e.g. 10, 20, 30
t_pct        <- if (length(args) >= 3) as.integer(args[3]) else 0 # % trusted, e.g. 0, 5, 10, 20
p_merge      <- if (length(args) >= 4) as.integer(args[4]) else 10

nodes        <- 1000
view         <- 16
nruns        <- 1
faulty_count <- as.integer(nodes * faulty_pct / 100)
t_count      <- as.integer(nodes * t_pct / 100)
strategy     <- "decay"
results_dir  <- "results_merge"

cat(sprintf("Reading: %s/%s-%d-%d-%d-%d-%d-%d-run*\n",
            results_dir, strategy, nodes, view, faulty_count, t_count, p_merge, budget))

# ── Style ─────────────────────────────────────────────────────────────────────
line_size  <- 0.7
width      <- 11
height     <- 3.5

all_colors    <- c("Global"  = "#000000",
                   "Honest"  = "#E69F00",
                   "Trusted" = "#56B4E9")
all_linetypes <- c("Global"  = "solid",
                   "Honest"  = "solid",
                   "Trusted" = "dashed")
ht_colors    <- c("Honest" = "#E69F00", "Trusted" = "#56B4E9")
ht_linetypes <- c("Honest" = "solid",   "Trusted" = "dashed")

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
  axis.text.x           = element_text(size = 11, face = "bold"),
  axis.text.y           = element_text(size = 11, face = "bold"),
  plot.title            = element_text(size = 12, face = "bold"),
  legend.text           = element_text(size = 11, face = "bold"),
  legend.title          = element_blank(),
  legend.background     = element_rect(fill = "transparent", colour = NA),
  legend.box.background = element_rect(fill = "transparent", colour = NA),
  axis.ticks            = element_line(color = "black", linewidth = 1)
)

#x_scale <- scale_x_log10(
 # breaks = c(1, 10, 100, 1000, 10000, 100000),
  #labels = c("1", "10", "100", "10^3", "10^4", "10^5"))

# ── Read data ─────────────────────────────────────────────────────────────────
group_cols <- c("h_avgByzN", "h_dkl", "h_f1", "h_biasErr",
                "t_avgByzN", "t_dkl", "t_f1", "t_biasErr",
                "avgByzSamp")

all_data <- data.frame()

for (run in 1:nruns) {
  fname <- file.path(results_dir,
                     sprintf("%s-%d-%d-%d-%d-%d-%d-run%d",
                             strategy, nodes, view, faulty_count,
                             t_count, p_merge, budget, run))
  if (!file.exists(fname)) {
    cat("Warning: file not found:", fname, "\n"); next
  }
  d <- read.table(fname, header = TRUE)
  d$time <- as.integer(d$time)
  d$run  <- run
  # Ensure group metric columns exist (backwards compat with old files)
  for (col in group_cols) {
    if (!col %in% names(d)) d[[col]] <- NA_real_
  }
  all_data <- rbind(all_data, d)
}

if (nrow(all_data) == 0) {
  cat("No data found. Check results_dir and file naming.\n"); quit(status = 1)
}

# Compute proportions
all_data$res   <- all_data$avgByzSamp / view
all_data$h_res <- all_data$h_avgByzN  / view
all_data$t_res <- all_data$t_avgByzN  / view

# Average over runs
avg <- all_data %>%
  group_by(time) %>%
  summarise(
    res    = mean(res,    na.rm = TRUE),
    h_res  = mean(h_res,  na.rm = TRUE),
    t_res  = mean(t_res,  na.rm = TRUE),
    h_dkl     = mean(h_dkl,     na.rm = TRUE),
    t_dkl     = mean(t_dkl,     na.rm = TRUE),
    h_f1      = mean(h_f1,      na.rm = TRUE),
    t_f1      = mean(t_f1,      na.rm = TRUE),
    h_biasErr = mean(h_biasErr, na.rm = TRUE),
    t_biasErr = mean(t_biasErr, na.rm = TRUE),
    .groups   = "drop"
  )

optimal <- faulty_pct / 100

# ── Panel 1: contamination ratio (Global, Honest, Trusted) ────────────────────
long_cr <- rbind(
  data.frame(time = avg$time, value = avg$cratio,   group = "Global"),
  data.frame(time = avg$time, value = avg$h_cratio, group = "Honest"),
  data.frame(time = avg$time, value = avg$t_cratio, group = "Trusted")
)

p_cr <- ggplot(long_cr, aes(x = time, y = value, color = group, linetype = group)) +
  geom_hline(yintercept = optimal, linetype = "dashed", color = "gray50") +
  geom_line(linewidth = line_size) +
  scale_color_manual(values = all_colors) +
  scale_linetype_manual(values = all_linetypes) +
  #x_scale +
  coord_cartesian(ylim = c(0, 1)) +
  scale_y_continuous(breaks = seq(0, 1, by = 0.2)) +
  labs(x = expression(bold("Time steps")),
       y = expression(bold("Prop. of Byz. samples"))) +
  mytheme +
  theme(legend.position = c(0.72, 0.85))

# ── Panel 2: DKL divergence (Honest and Trusted) ──────────────────────────────
long_dkl <- rbind(
  data.frame(time = avg$time, value = avg$h_dkl, group = "Honest"),
  data.frame(time = avg$time, value = avg$t_dkl, group = "Trusted")
)

p_dkl <- ggplot(long_dkl, aes(x = time, y = value, color = group, linetype = group)) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "gray50") +
  geom_line(linewidth = line_size) +
  scale_color_manual(values = ht_colors) +
  scale_linetype_manual(values = ht_linetypes) +
  #x_scale +
  labs(x = expression(bold("Time steps")),
       y = expression(bold("DKL"))) +
  mytheme +
  theme(legend.position = "none")

# ── Panel 3: F1 score (Honest and Trusted) ────────────────────────────────────
long_f1 <- rbind(
  data.frame(time = avg$time, value = avg$h_f1, group = "Honest"),
  data.frame(time = avg$time, value = avg$t_f1, group = "Trusted")
)

p_f1 <- ggplot(long_f1, aes(x = time, y = value, color = group, linetype = group)) +
  geom_line(linewidth = line_size) +
  scale_color_manual(values = ht_colors) +
  scale_linetype_manual(values = ht_linetypes) +
  #x_scale +
  coord_cartesian(ylim = c(0, 1)) +
  scale_y_continuous(breaks = seq(0, 1, by = 0.2)) +
  labs(x = expression(bold("Time steps")),
       y = expression(bold("F1"))) +
  mytheme +
  theme(legend.position = c(0.72, 0.20))

# ── Panel 4: Bias factor error (Honest and Trusted) ───────────────────────────
long_bias <- rbind(
  data.frame(time = avg$time, value = avg$h_biasErr, group = "Honest"),
  data.frame(time = avg$time, value = avg$t_biasErr, group = "Trusted")
)

p_bias <- ggplot(long_bias, aes(x = time, y = value, color = group, linetype = group)) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "gray50") +
  geom_line(linewidth = line_size) +
  scale_color_manual(values = ht_colors) +
  scale_linetype_manual(values = ht_linetypes) +
  #x_scale +
  labs(x = expression(bold("Time steps")),
       y = expression(bold("Bias factor err."))) +
  mytheme +
  theme(legend.position = "none")

# ── Save PDF ──────────────────────────────────────────────────────────────────
dir.create("results", showWarnings = FALSE)
outfile <- sprintf("results/metrics_evolution_f%d_t%d_b%d.pdf", faulty_pct, t_pct, budget)
pdf(outfile, width = width * 4/3, height = height)
grid.arrange(p_cr, p_dkl, p_f1, p_bias, nrow = 1, ncol = 4)
dev.off()
cat("Saved to:", outfile, "\n")
