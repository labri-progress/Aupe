#!/usr/bin/env Rscript
# Usage: Rscript plot_byz_trusted.r <budget> [<merge_subdir>]
# Example: Rscript plot_byz_trusted.r 1 attack1KB
#   Produces a PDF with 3 side-by-side plots (f=10,20,30) for the given budget,
#   showing BM / BMDecay / Array (no trusted, from output_byz) plus
#   BMDecay t=5%, t=10%, t=20% (from results_merge/<merge_subdir>).

args <- commandArgs(trailingOnly = TRUE)

library(ggplot2)
library(dplyr)
library(gridExtra)

# --- Parameters ---
budget       <- as.numeric(args[1])            # 0.5, 1, or 2 (KB)
merge_subdir <- if (length(args) >= 2) args[2] else "attack"

nodes        <- 1000
view         <- 20
nruns        <- 1
p_merge      <- 10
faulty_pcts  <- c(10, 20, 30)
trusted_pcts <- c(5, 10, 20)   # trusted proportions for BMDecay lines

results_dir  <- "output_byz"
merge_dir    <- "output_byz" #file.path("results_merge", merge_subdir)

# --- Theme ---
line_size  <- 0.1 #0.5
point_size <- 1 #1.5
ratio      <- 3
width      <- 11
height     <- width / ratio

custom_colors <- c(
  "BM"             = "#882EE6",
  "BMDecay"        = "#000000",
  "Array"          = "#ff3333",
  "BMDecay t=5%"   = "#E69F00",
  "BMDecay t=10%"  = "#56B4E9",
  "BMDecay t=20%"  = "#009E73", 
  "Array t=5%"    = "#E69F00",
  "Array t=10%"   = "#56B4E9",
  "Array t=20%"   = "#009E73"
)

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

# --- Common columns ---
common_cols <- c("time", "n_sent", "n_recv", "avgRecv", "avgByzRecv", "pByzRecv", "avgByzN")

# --- Part 1: Read BM / BMDecay / Array from output_byz (no trusted nodes) ---
#strategies_base  <- c("xbm", "xdec", "xarray")
#strat_labels_base <- c("xbm" = "BM", "xdec" = "BMDecay", "xarray" = "Array")

strategies_base  <- c("bm", "decay", "array")
strat_labels_base <- c("bm" = "BM", "decay" = "BMDecay", "array" = "Array")

base_data <- data.frame()

for (strat in strategies_base) {
  for (f_pct in faulty_pcts) {
    faulty_count <- as.integer(nodes * f_pct / 100)
    for (run in 1:nruns) {
      if (strat == "array") { #"xarray") {
        fname <- file.path(results_dir,
                           sprintf("%s-N%d-v%d-f%d-run%d", strat, nodes, view, faulty_count, run))
      } else {
        fname <- file.path(results_dir,
                           sprintf("%s-N%d-v%d-f%d-y%g-run%d", strat, nodes, view, faulty_count, budget, run))
      }
      if (!file.exists(fname)) {
        cat("Warning: file not found:", fname, "\n"); next
      }
      d <- read.table(fname, header = TRUE)
      d <- d[, intersect(names(d), common_cols), drop = FALSE]
      d$time     <- as.integer(d$time)
      d$strategy <- strat_labels_base[[strat]]
      d$f_pct    <- f_pct
      d$run      <- run
      base_data  <- rbind(base_data, d)
    }
  }
}

# --- Part 2: Read BMDecay with trusted nodes from results_merge ---
trusted_data <- data.frame()

#for (strat in strategies_base) {
#strat <- "xdec" # only BMDecay has trusted node variants
strat <- "decay"
for (t_pct in trusted_pcts) {
  t_count <- as.integer(nodes * t_pct / 100)
  for (f_pct in faulty_pcts) {
    faulty_count <- as.integer(nodes * f_pct / 100)
    for (run in 1:nruns) {
      if (strat == "array") { #"xarray") {
        fname <- file.path(results_dir,
                           sprintf("%s-N%d-v%d-f%d-x%d-run%d",
                                 strat, nodes, view, faulty_count, t_count, run))
      } else {
        fname <- file.path(merge_dir,
                         sprintf("%s-N%d-v%d-f%d-y%.1g-x%d-run%d",
                                 strat, nodes, view, faulty_count, budget, t_count, run))
      }
      if (!file.exists(fname)) {
        cat("Warning: file not found:", fname, "\n"); next
      }
      d <- read.table(fname, header = TRUE)
      d <- d[, intersect(names(d), common_cols), drop = FALSE]
      d$time     <- as.integer(d$time)

      d$strategy <- paste0(strat_labels_base[[strat]], " t=", t_pct, "%")
      print(unique(d$strategy))
      d$f_pct    <- f_pct
      d$run      <- run
      trusted_data <- rbind(trusted_data, d)
    }
  }
}
#}
# --- Combine and compute propByz ---
all_data <- rbind(base_data, trusted_data)
all_data$propByz <- all_data$avgByzN / view

# filter time between 100 and round_to_stop
#round_to_stop <- 12000
#all_data <- all_data[all_data$time >= 9999 & all_data$time <= round_to_stop, ]

# Average over runs
avg_data <- all_data %>%
  group_by(strategy, f_pct, time) %>%
  summarise(propByz = mean(propByz), .groups = "drop")

# Keep one point every `step` rounds
step <- 100
avg_data <- avg_data %>% filter(time %% step == 0)

strat_order <- c("BM", "BMDecay", "Array", #paste0("Array t=", trusted_pcts, "%"),
                 paste0("BMDecay t=", trusted_pcts, "%"))
avg_data$strategy <- factor(avg_data$strategy,
                             levels = intersect(strat_order, unique(avg_data$strategy)))
print(unique(avg_data$strategy))
# --- Plotting function ---
byz_plot <- function(data, f, show_legend = TRUE, show_y_title = TRUE) {
  optimal <- f / 100

  p <- ggplot(data, aes(x = time, y = propByz, color = strategy, group = strategy)) +
    geom_hline(yintercept = optimal, linetype = "dashed", color = "gray50") +
    geom_line(linewidth = line_size) +
    scale_color_manual(values = custom_colors,
                       drop = FALSE) +
    labs(
      x = expression(bold("Rounds")),
      y = if (show_y_title) expression(bold("Proportion of Byz. samp.")) else NULL
    ) +
    coord_cartesian(ylim = c(0, 1)) +
    scale_x_continuous(breaks = c(0, 5000, 10000, 15000, 20000),
                       labels = c("0", "5K", "10K", "15K", "20K")) +
    scale_y_continuous(breaks = seq(0, 1, by = 0.2)) +
    mytheme +
    theme(
      legend.position = if (show_legend) c(0.5, 0.75) else "none"
    ) +
    guides(color = guide_legend(ncol = 2))

  return(p)
}

# --- Build 3 plots ---
plots <- list()
for (i in seq_along(faulty_pcts)) {
  f   <- faulty_pcts[i]
  sub <- avg_data %>% filter(f_pct == f)
  plots[[i]] <- byz_plot(sub, f,
                         show_legend  = (i == 3),
                         show_y_title = (i == 3))
}

# --- Save PDF ---
dir.create("results", showWarnings = FALSE)
outfile <- sprintf("results/byz_trusted_budget_%gKB_%s.pdf", budget, merge_subdir)
pdf(outfile, width = width, height = height)
grid.arrange(grobs = plots, nrow = 1, ncol = 3)
dev.off()
cat("Saved to:", outfile, "\n")
