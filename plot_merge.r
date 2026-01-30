#!/usr/bin/env Rscript
# Usage: Rscript plot_merge.r <faulty_pct> <budget> <p>
# Example: Rscript plot_merge.r 30 10 1
#   faulty_pct: Byzantine percentage (30)
#   budget:     budget memory in KB (10 or 20), used for BM filenames
#   p:          number of merges per trusted node per round (1 or 10)
#
# Outputs one figure with BM and Array, 3 lines per strategy (t=1%,5%,10%).

args <- commandArgs(trailingOnly = TRUE)

library(ggplot2)
library(dplyr)
library(scales)

# --- Parameters ---
faulty_pct   <- as.integer(args[1])  # e.g. 30
budget       <- as.integer(args[2])  # e.g. 10 or 20
p_merge      <- as.integer(args[3])  # e.g. 1 or 10
nodes        <- 10000
view         <- 160
nruns        <- 2
force        <- 10
faulty_count <- as.integer(nodes * faulty_pct / 100)
strategies   <- c("bm", "array")
strat_labels <- c("bm" = "BM", "array" = "Array")
trusted_pcts <- c(10, 20, 30) #c(1, 5, 10)
trusted_counts <- as.integer(nodes * trusted_pcts / 100)
trusted_counts
results_dir  <- "output_merge"

# --- Theme ---
line_size  <- 0.5
point_size <- 1.5
ratio      <- 2.5
width      <- 7
height     <- width / ratio

custom_colors <- c("BM" = "#882EE6", "Array" = "#ff8833")
custom_linetypes <- c("10" = "dotted", "20" = "dashed", "30" = "solid")

mytheme <- theme(
  panel.grid.major   = element_blank(),
  panel.grid.minor   = element_blank(),
  panel.background   = element_rect(fill = "white"),
  plot.background    = element_rect(fill = "white"),
  panel.border       = element_rect(colour = "black", linewidth = 1, fill = NA),
  legend.spacing.y   = unit(0.005, "cm"),
  text               = element_text(size = 12, color = "black"),
  axis.title.x       = element_text(size = 14, face = "bold"),
  axis.title.y       = element_text(size = 12, face = "bold"),
  axis.text.x        = element_text(size = 14, face = "bold"),
  axis.text.y        = element_text(size = 14, face = "bold"),
  plot.title          = element_text(size = 14, face = "bold"),
  legend.text        = element_text(size = 11, face = "bold"),
  legend.title       = element_blank(),
  legend.background  = element_rect(fill = "transparent", colour = NA),
  legend.box.background = element_rect(fill = "transparent", colour = NA),
  axis.ticks         = element_line(color = "black", linewidth = 1)
)

# --- Read and aggregate data ---
all_data <- data.frame()

for (strat in strategies) {
  for (ti in seq_along(trusted_pcts)) {
    t_pct   <- trusted_pcts[ti]
    t_count <- trusted_counts[ti]

    for (run in 1:nruns) {
      if (strat == "array") {
        fname <- file.path(results_dir,
                           sprintf("%s-%d-%d-%d-%d-%d-run%d",
                                   strat, nodes, view, faulty_count, t_count, p_merge, run))
      } else {
        fname <- file.path(results_dir,
                           sprintf("%s-%d-%d-%d-%d-%d-%d-run%d",
                                   strat, nodes, view, faulty_count, t_count, p_merge, budget, run))
      }
      if (!file.exists(fname)) {
        cat("Warning: file not found:", fname, "\n")
        next
      }
      d <- read.table(fname, header = TRUE)
      d$time      <- as.integer(d$time)
      d$strategy  <- strat_labels[[strat]]
      d$t_pct     <- t_pct
      d$run       <- run
      all_data    <- rbind(all_data, d)
    }
  }
}

# Compute proportion of Byzantine
all_data$propByz <- all_data$avgByzN / view

# Average over runs
avg_data <- all_data %>%
  group_by(strategy, t_pct, time) %>%
  summarise(propByz = mean(propByz), .groups = "drop")

avg_data$t_pct_f <- factor(avg_data$t_pct)
unique(avg_data$t_pct_f)
unique(avg_data$t_pct)
# --- Plot ---
optimal <- faulty_pct / 100

max_time <- max(avg_data$time)
if (max_time > 50) {
  x_breaks <- seq(0, max_time, by = 50)
} else {
  x_breaks <- sort(unique(avg_data$time))
}
avg_data$label  <- paste0(avg_data$strategy, " t=", avg_data$t_pct, "%")
unique(avg_data$label)
p <- ggplot(avg_data, aes(x = time, y = propByz,
                           color = strategy,
                           linetype = t_pct_f,
                           group = interaction(strategy, t_pct_f))) +
  geom_hline(yintercept = optimal, linetype = "dashed", color = "gray50") +
  geom_line(linewidth = line_size) +
  #geom_point(size = point_size) +
  scale_color_manual(values = custom_colors) +
  scale_linetype_manual(values = custom_linetypes,
                        labels = paste0("t=", names(custom_linetypes), "%")) +
  labs(
    x = expression(bold("Time steps")),
    y = expression(bold("Proportion of Byz. samp."))
  ) +
  coord_cartesian(ylim = c(0, 1)) +
  scale_x_continuous(breaks = x_breaks) +
  scale_y_continuous(breaks = seq(0, 1, by = 0.2)) +
  mytheme +
  theme(
    legend.position = c(0.25, 0.55),
    legend.title = element_blank(),
    legend.box = "horizontal"
  ) +
  guides(color = guide_legend(ncol = 1, order = 1),
         linetype = guide_legend(ncol = 1, order = 2))

# --- Save PDF ---
dir.create("results", showWarnings = FALSE)
outfile <- sprintf("results/merge_byz_f%d_b%d_p%d.pdf", faulty_pct, budget, p_merge)
pdf(outfile, width = width, height = height)
print(p)
dev.off()
cat("Saved to:", outfile, "\n")
