#!/usr/bin/env Rscript
# Plot resilience evolution (propByz over rounds) for Decay and Array strategies,
# with and without trusted-node merge variants.
#
# Usage: Rscript plot_resilience_merge.r [faulty_count] [budget_decay]
#   faulty_count  : number of faulty nodes (default 300)
#   budget_decay  : bandwidth budget for decay (default 1)
#
# Reads:
#   decay  <- results_merge/decay/decay-{N}-{v}-{f}-{trusted}-{p_merge}-{budget}-run{n}
#   array  <- results_merge/array-{N}-{v}-{f}-{trusted}-{p_merge_array}-run{n}

args <- commandArgs(trailingOnly = TRUE)

library(ggplot2)
library(dplyr)
library(gridExtra)

# ---- Parameters ----
nodes         <- 1000
view          <- 20
faulty_count  <- if (length(args) >= 1) as.integer(args[1]) else 300
budget_decay  <- if (length(args) >= 2) as.numeric(args[2])  else 0.5
p_merge_decay <- 1
p_merge_array <- 1

trusted_decay <- c(0, 50, 200)   # available for decay
trusted_array <- c(0, 50, 200)        # available for array
nruns_max     <- 1                     # try runs 1..nruns_max

results_root <- "results_merge"
decay_dir    <- results_root #file.path(results_root, "decay")

step <- 100   # keep one point every `step` rounds

# ---- Colours ----
custom_colors <- c(
  "Decay"         = "#000000",
  "Decay t=5%"    = "#E69F00",
  "Decay t=10%"   = "#56B4E9",
  "Decay t=20%"   = "#009E73",
  "Array"         = "#ff3333",
  "Array t=5%"    = "#E69F00",
  "Array t=10%"   = "#56B4E9",
  "Array t=20%"   = "#009E73"
)

line_types <- c(
  "Decay"         = "solid",
  "Decay t=5%"    = "solid",
  "Decay t=10%"   = "solid",
  "Decay t=20%"   = "solid",
  "Array"         = "dashed",
  "Array t=5%"    = "dashed",
  "Array t=10%"   = "dashed",
  "Array t=20%"   = "dashed"
)

# ---- Theme ----
line_size  <- 0.5
point_size <- 1.5
ratio      <- 2
width      <- 10
height     <- width / ratio

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
  axis.text.x           = element_text(size = 14, face = "bold"),
  axis.text.y           = element_text(size = 14, face = "bold"),
  plot.title            = element_text(size = 14, face = "bold"),
  legend.text           = element_text(size = 11, face = "bold"),
  legend.title          = element_blank(),
  legend.background     = element_rect(fill = "transparent", colour = NA),
  legend.box.background = element_rect(fill = "transparent", colour = NA),
  axis.ticks            = element_line(color = "black", linewidth = 1)
)

# ---- Common columns ----
common_cols <- c("time", "n_sent", "n_recv", "avgRecv", "avgByzRecv",
                 "pByzRecv", "avgByzN")

# ---- Helper: trusted count -> label suffix ----
trusted_label <- function(t_count) {
  pct <- round(t_count / nodes * 100)
  if (pct == 0) "" else paste0(" t=", pct, "%")
}

# ---- Read decay files ----
decay_data <- data.frame()

for (t in trusted_decay) {
  lbl <- paste0("Decay", trusted_label(t))
  for (run in 1:nruns_max) {
    fname <- file.path(decay_dir,
                       sprintf("decay-%d-%d-%d-%d-%d-%g-run%d",
                               nodes, view, faulty_count, t,
                               p_merge_decay, budget_decay, run))
    if (!file.exists(fname)) { cat("Not found:", fname, "\n"); next }
    d <- read.table(fname, header = TRUE)
    d <- d[, intersect(names(d), common_cols), drop = FALSE]
    d$time     <- as.integer(d$time)
    d$strategy <- lbl
    d$run      <- run
    decay_data <- rbind(decay_data, d)
  }
}

# ---- Read array files ----
array_data <- data.frame()

for (t in trusted_array) {
  lbl <- paste0("Array", trusted_label(t))
  for (run in 1:nruns_max) {
    fname <- file.path(results_root,
                       sprintf("array-%d-%d-%d-%d-%d-run%d",
                               nodes, view, faulty_count, t,
                               p_merge_array, run))
    if (!file.exists(fname)) { cat("Not found:", fname, "\n"); next }
    d <- read.table(fname, header = TRUE)
    d <- d[, intersect(names(d), common_cols), drop = FALSE]
    d$time     <- as.integer(d$time)
    d$strategy <- lbl
    d$run      <- run
    array_data <- rbind(array_data, d)
  }
}

# ---- Combine, compute propByz, average over runs ----
all_data <- rbind(decay_data, array_data)
if (nrow(all_data) == 0) stop("No data loaded — check file paths and parameters.")

all_data$propByz <- all_data$avgByzN / view

avg_data <- all_data %>%
  group_by(strategy, time) %>%
  summarise(propByz = mean(propByz, na.rm = TRUE), .groups = "drop") %>%
  filter(time < 200 || time %% step == 0)

# Ordered factor for consistent legend
strat_order <- c(
  "Decay",
  paste0("Decay t=", c(5, 10, 20), "%"),
  "Array",
  paste0("Array t=", c(5, 10, 20), "%")
)
avg_data$strategy <- factor(avg_data$strategy,
                             levels = intersect(strat_order, unique(avg_data$strategy)))

cat("Strategies loaded:", paste(levels(avg_data$strategy), collapse = ", "), "\n")

# ---- Plotting function ----
make_plot <- function(data, title_str, show_legend = TRUE, show_y = TRUE) {
  optimal <- faulty_count / nodes

  ggplot(data, aes(x = time, y = propByz,
                   color = strategy, linetype = strategy, group = strategy)) +
    geom_hline(yintercept = optimal, linetype = "dotted", color = "gray50") +
    geom_line(linewidth = line_size) +
    scale_color_manual(values = custom_colors, drop = FALSE) +
    scale_linetype_manual(values = line_types, drop = FALSE) +
    labs(
      title = title_str,
      x     = expression(bold("Rounds")),
      y     = if (show_y) expression(bold("Prop. Byz. samp.")) else NULL
    ) +
    coord_cartesian(ylim = c(0, 1)) +
    scale_x_continuous(breaks = c(0, 200, 500, 1000, 5000, 10000, 15000, 20000),
                       labels = c("0", "200", "500", "1K", "5K", "10K", "15K", "20K")) +
    scale_y_continuous(breaks = seq(0, 1, by = 0.2)) +
    mytheme +
    theme(legend.position = if (show_legend) c(0.72, 0.78) else "none") +
    guides(color    = guide_legend(ncol = 2),
           linetype = guide_legend(ncol = 2))
}

# ---- Build two panels: Decay | Array ----
decay_sub <- avg_data %>% filter(grepl("^Decay", strategy))
array_sub <- avg_data %>% filter(grepl("^Array", strategy))

f_pct <- round(faulty_count / nodes * 100)

p_decay <- make_plot(decay_sub,
                     sprintf("Decay  (f = %d%%)", f_pct),
                     show_legend = TRUE,
                     show_y      = TRUE)

p_array <- make_plot(array_sub,
                     sprintf("Array  (f = %d%%)", f_pct),
                     show_legend = TRUE,
                     show_y      = FALSE)

# ---- Save ----
dir.create("results", showWarnings = FALSE)
outfile <- sprintf("results/resilience_merge_f%d_b%g.pdf", faulty_count, budget_decay)
pdf(outfile, width = width, height = height)
grid.arrange(p_decay, p_array, nrow = 1, ncol = 2)
dev.off()
cat("Saved to:", outfile, "\n")
