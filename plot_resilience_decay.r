#!/usr/bin/env Rscript
# Usage: Rscript plot_resilience_decay.r <faulty_pct> <budget> <p_merge>
# Example: Rscript plot_resilience_decay.r 30 1 10
#
# Shows the contamination ratio over time for the BMDecay strategy with
# different amounts of trusted nodes (t = 0%, 5%, 10%, 20%).
# Inspired by plot_mergeandNomergeFloat.r.
#
# Data is read from results_merge/ with format:
#   decay-{nodes}-{view}-{faulty_count}-{t_count}-{p_merge}-{budget}-run{run}
#
# Output: results/resilience_decay_f<faulty_pct>_b<budget>_p<p_merge>.pdf

args <- commandArgs(trailingOnly = TRUE)

library(ggplot2)
library(dplyr)
library(scales)

# ── Parameters ────────────────────────────────────────────────────────────────
faulty_pct   <- as.integer(args[1])  # e.g. 30
budget       <- as.integer(args[2])  # e.g. 1
p_merge      <- as.integer(args[3])  # e.g. 10

nodes        <- 1000
view         <- 16
nruns        <- 1
faulty_count <- as.integer(nodes * faulty_pct / 100)
strategy     <- "decay"
results_dir  <- "results_merge"

trusted_pcts   <- c(0, 5, 10, 20)
trusted_counts <- as.integer(nodes * trusted_pcts / 100)

# ── Style ─────────────────────────────────────────────────────────────────────
line_size  <- 0.7
width      <- 7
height     <- 3.5

custom_colors    <- c("0"  = "#000000",
                      "5"  = "#E69F00",
                      "10" = "#56B4E9",
                      "20" = "#009E73")
custom_linetypes <- c("0"  = "solid",
                      "5"  = "solid",
                      "10" = "solid",
                      "20" = "solid")

mytheme <- theme(
  panel.grid.major      = element_blank(),
  panel.grid.minor      = element_blank(),
  panel.background      = element_rect(fill = "white"),
  plot.background       = element_rect(fill = "white"),
  panel.border          = element_rect(colour = "black", linewidth = 1, fill = NA),
  legend.spacing.y      = unit(0.005, "cm"),
  text                  = element_text(size = 12, color = "black"),
  axis.title.x          = element_text(size = 14, face = "bold"),
  axis.title.y          = element_text(size = 12, face = "bold"),
  axis.text.x           = element_text(size = 12, face = "bold"),
  axis.text.y           = element_text(size = 12, face = "bold"),
  plot.title            = element_text(size = 12, face = "bold"),
  legend.text           = element_text(size = 12, face = "bold"),
  legend.title          = element_blank(),
  legend.background     = element_rect(fill = "transparent", colour = NA),
  legend.box.background = element_rect(fill = "transparent", colour = NA),
  axis.ticks            = element_line(color = "black", linewidth = 1)
)

# ── Read data ─────────────────────────────────────────────────────────────────
group_cols <- c("h_avgByzN", "h_dkl", "h_f1", "h_biasErr",
                "t_avgByzN", "t_dkl", "t_f1", "t_biasErr")

all_data <- data.frame()

for (ti in seq_along(trusted_pcts)) {
  t_pct   <- trusted_pcts[ti]
  t_count <- trusted_counts[ti]

  for (run in 1:nruns) {
    fname <- file.path(results_dir,
                       sprintf("%s-%d-%d-%d-%d-%d-%d-run%d",
                               strategy, nodes, view, faulty_count,
                               t_count, p_merge, budget, run))
    if (!file.exists(fname)) {
      cat("Warning: file not found:", fname, "\n"); next
    }
    d <- read.table(fname, header = TRUE)
    d$time  <- as.integer(d$time)
    d$t_pct <- t_pct
    d$run   <- run
    # Ensure group metric columns exist (backwards compat with old files)
    for (col in group_cols) {
      if (!col %in% names(d)) d[[col]] <- NA_real_
    }
    all_data <- rbind(all_data, d)
  }
}

if (nrow(all_data) == 0) {
  cat("No data found. Check results_dir and file naming.\n"); quit(status = 1)
}

# Contamination ratio = avgByzN / view
all_data$cratio <- all_data$avgByzN / view

# Average over runs
avg_data <- all_data %>%
  group_by(t_pct, time) %>%
  summarise(cratio = mean(cratio, na.rm = TRUE), .groups = "drop")

optimal <- faulty_pct / 100

# Build label and factor for legend
avg_data$label <- ifelse(
  avg_data$t_pct == 0,
  "BMDecay",
  paste0("BMDecay(t=", avg_data$t_pct, "%)")
)
avg_data$label_f <- factor(avg_data$label, levels = unique(avg_data$label[order(avg_data$t_pct)]))

# Build color mapping keyed by t_pct
label_color_map <- avg_data %>%
  distinct(label_f, t_pct) %>%
  mutate(color = custom_colors[as.character(t_pct)])
label_colors <- setNames(label_color_map$color, label_color_map$label_f)

# X-axis breaks
max_time <- max(avg_data$time)
if (max_time > 200) {
  x_breaks <- seq(0, max_time, by = 250)
} else if (max_time > 50) {
  x_breaks <- seq(0, max_time, by = 50)
} else {
  x_breaks <- sort(unique(avg_data$time))
}

# ── Plot ──────────────────────────────────────────────────────────────────────
p <- ggplot(avg_data, aes(x = time, y = cratio,
                          color = label_f, group = label_f)) +
  geom_hline(yintercept = optimal, linetype = "dashed", color = "gray50") +
  geom_line(linewidth = line_size) +
  scale_color_manual(values = label_colors) +
  labs(
    x = expression(bold("Time steps")),
    y = expression(bold("Cont. ratio"))
  ) +
  coord_cartesian(ylim = c(0, 1)) +
  scale_x_continuous(breaks = x_breaks) +
  scale_y_continuous(breaks = seq(0, 1, by = 0.2)) +
  mytheme +
  theme(
    legend.position = c(0.55, 0.85),
    legend.title    = element_blank(),
    legend.box      = "horizontal"
  ) +
  guides(color = guide_legend(ncol = 2))

# ── Save PDF ──────────────────────────────────────────────────────────────────
dir.create("results", showWarnings = FALSE)
outfile <- sprintf("results/resilience_decay_f%d_b%d_p%d.pdf", faulty_pct, budget, p_merge)
pdf(outfile, width = width, height = height)
print(p)
dev.off()
cat("Saved to:", outfile, "\n")
