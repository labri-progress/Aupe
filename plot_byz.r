#!/usr/bin/env Rscript
# Usage: Rscript plot_byz.r <budget>
# Example: Rscript plot_byz.r 1
#   Produces a PDF with 3 side-by-side plots (f=10,20,30) for the given budget.

args <- commandArgs(trailingOnly = TRUE)

library(ggplot2)
library(dplyr)
library(gridExtra)

# --- Parameters ---
budget       <- as.integer(args[1])  # 1 or 2 (KB)
nodes        <- 1000
view         <- 100
nruns        <- 5
faulty_pcts  <- c(10, 20, 30)
strategies   <- c("bm", "decay", "array")
strat_labels <- c("bm" = "BM", "decay" = "BMDecay", "array" = "Array")
results_dir  <- "output_byz"

# --- Theme (inspired by metricmemory_force.r) ---
line_size  <- 0.5
point_size <- 1.5
ratio      <- 3
width      <- 11
height     <- width / ratio

custom_colors <- c("BM" = "#882EE6", "BMDecay" = "#000000", "Array" = "#ff8833")

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
  for (f_pct in faulty_pcts) {
    for (run in 1:nruns) {
      if (strat == "array") {
        fname <- file.path(results_dir,
                           sprintf("%s-N%d-v%d-f%d-run%d", strat, nodes, view, f_pct, run))
      } else {
        fname <- file.path(results_dir,
                           sprintf("%s-N%d-v%d-f%d-y%d-run%d", strat, nodes, view, f_pct, budget, run))
      }
      if (!file.exists(fname)) {
        cat("Warning: file not found:", fname, "\n")
        next
      }
      d <- read.table(fname, header = TRUE)
      d$time     <- as.integer(d$time)
      d$strategy <- strat_labels[[strat]]
      d$f_pct    <- f_pct
      d$run      <- run
      all_data   <- rbind(all_data, d)
    }
  }
}

# Compute proportion of Byzantine
all_data$propByz <- all_data$avgByzN / view

# Average over runs
avg_data <- all_data %>%
  group_by(strategy, f_pct, time) %>%
  summarise(propByz = mean(propByz), .groups = "drop")

# --- Plotting function ---
byz_plot <- function(data, f, show_legend = TRUE, show_y_title = TRUE) {
  optimal <- f / 100

  data$time_f <- factor(data$time)

  p <- ggplot(data, aes(x = time_f, y = propByz, color = strategy, group = strategy)) +
    geom_hline(yintercept = optimal, linetype = "dashed", color = "gray50") +
    geom_line(linewidth = line_size) +
    geom_point(size = point_size) +
    scale_color_manual(values = custom_colors) +
    labs(
      x = expression(bold("Time steps")),
      y = if (show_y_title) expression(bold("Proportion of Byz. samp.")) else NULL
    ) +
    coord_cartesian(ylim = c(0, 1)) +
    scale_y_continuous(breaks = seq(0, 1, by = 0.2)) +
    mytheme +
    theme(
      legend.position = if (show_legend) c(0.5, 0.85) else "none"
    ) +
    guides(color = guide_legend(ncol = 1))

  return(p)
}

# --- Build 3 plots ---
plots <- list()
for (i in seq_along(faulty_pcts)) {
  f <- faulty_pcts[i]
  sub <- avg_data %>% filter(f_pct == f)
  plots[[i]] <- byz_plot(sub, f,
                         show_legend  = (i == 1),
                         show_y_title = (i == 1))
}

# --- Save PDF ---
dir.create("results", showWarnings = FALSE)
outfile <- sprintf("results/byz_proportion_budget_%dKB.pdf", budget)
pdf(outfile, width = width, height = height)
grid.arrange(grobs = plots, nrow = 1, ncol = 3)
dev.off()
cat("Saved to:", outfile, "\n")
