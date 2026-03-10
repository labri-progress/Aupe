#!/usr/bin/env Rscript
# Usage: Rscript plot_metrics_trusted.r <budget> [<merge_subdir>]
# Example: Rscript plot_metrics_trusted.r 0.5 attack
#   Produces PDFs with metric plots (h_dkl, h_f1, h_biasErr, h_division)
#   grouped by faulty percentage (f=10,20,30), showing BM / BMDecay / Array
#   plus BMDecay t=5%, t=10%, t=20% (trusted nodes, x-prefixed files in merge_dir).

args <- commandArgs(trailingOnly = TRUE)

library(ggplot2)
library(dplyr)
library(gridExtra)

# --- Parameters ---
budget       <- as.numeric(args[1])
merge_subdir <- if (length(args) >= 2) args[2] else "attack"

nodes        <- 1000
view         <- 20
nruns        <- 1
faulty_pcts  <- c(10, 20, 30)
trusted_pcts <- c(5, 10, 20)   # trusted proportions for BMDecay lines

results_dir  <- "output_byz"
merge_dir    <- "output_byz"   # trusted files are co-located in output_byz

# --- Theme ---
line_size  <- 0.5
ratio      <- 3
width      <- 11
height     <- width / ratio

custom_colors <- c(
  "BM"            = "#882EE6",
  "BMDecay"       = "#000000",
  "Array"         = "#ff8833",
  "BMDecay t=5%"  = "#E69F00",
  "BMDecay t=10%" = "#56B4E9",
  "BMDecay t=20%" = "#009E73"
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

# --- y-axis metadata for standard metrics ---
y_axis_settings <- list(
  h_dkl     = list(title = expression(bold("h(DKL)")),     limits = c(0, NA), breaks = waiver()),
  h_f1      = list(title = expression(bold("h(F1)")),      limits = c(0, 1),  breaks = seq(0, 1, by = 0.2)),
  h_biasErr = list(title = expression(bold("h(BiasErr)")), limits = c(0, NA), breaks = waiver())
)

# --- Part 1: Read BM / BMDecay / Array from output_byz (no trusted nodes) ---
strategies_base   <- c("bm", "decay", "array")
strat_labels_base <- c("bm" = "BM", "decay" = "BMDecay", "array" = "Array")

base_data <- data.frame()

for (strat in strategies_base) {
  for (f_pct in faulty_pcts) {
    faulty_count <- as.integer(nodes * f_pct / 100)
    for (run in 1:nruns) {
      if (strat == "array") {
        fname <- file.path(results_dir,
                           sprintf("%s-N%d-v%d-f%d-run%d", strat, nodes, view, faulty_count, run))
      } else {
        fname <- file.path(results_dir,
                           sprintf("%s-N%d-v%d-f%d-y%g-run%d", strat, nodes, view, faulty_count, budget, run))
      }
      if (!file.exists(fname)) { cat("Warning: file not found:", fname, "\n"); next }
      d <- read.table(fname, header = TRUE)
      d$time     <- as.integer(d$time)
      d$strategy <- strat_labels_base[[strat]]
      d$f_pct    <- f_pct
      d$run      <- run
      if (!"h_blocked"  %in% names(d)) d$h_blocked  <- NA_real_
      if (!"h_division" %in% names(d)) d$h_division <- NA_real_
      keep <- c("time", "strategy", "f_pct", "run",
                "h_dkl", "h_f1", "h_biasErr", "h_blocked", "h_division")
      base_data <- rbind(base_data, d[, keep])
    }
  }
}

# --- Part 2: Read BMDecay t=i% from merge_dir (x-prefixed filenames) ---
trusted_data <- data.frame()

for (t_pct in trusted_pcts) {
  t_count <- as.integer(nodes * t_pct / 100)
  for (f_pct in faulty_pcts) {
    faulty_count <- as.integer(nodes * f_pct / 100)
    for (run in 1:nruns) {
      fname <- file.path(merge_dir,
                         sprintf("decay-N%d-v%d-f%d-y%.1g-x%d-run%d",
                                 nodes, view, faulty_count, budget, t_count, run))
      if (!file.exists(fname)) { cat("Warning: file not found:", fname, "\n"); next }
      d <- read.table(fname, header = TRUE)
      d$time     <- as.integer(d$time)
      d$strategy <- paste0("BMDecay t=", t_pct, "%")
      d$f_pct    <- f_pct
      d$run      <- run
      if (!"h_blocked"  %in% names(d)) d$h_blocked  <- NA_real_
      if (!"h_division" %in% names(d)) d$h_division <- NA_real_
      keep <- c("time", "strategy", "f_pct", "run",
                "h_dkl", "h_f1", "h_biasErr", "h_blocked", "h_division")
      trusted_data <- rbind(trusted_data, d[, keep])
    }
  }
}

# --- Combine and average over runs ---
all_data <- rbind(base_data, trusted_data)

avg_data <- all_data %>%
  group_by(strategy, f_pct, time) %>%
  summarise(
    h_dkl      = mean(h_dkl,      na.rm = TRUE),
    h_f1       = mean(h_f1,       na.rm = TRUE),
    h_biasErr  = mean(h_biasErr,  na.rm = TRUE),
    h_blocked  = mean(h_blocked,  na.rm = TRUE),
    h_division = mean(h_division, na.rm = TRUE),
    .groups = "drop"
  )

# Fix factor order for legend
strat_order <- c("BM", "BMDecay", "Array",
                 paste0("BMDecay t=", trusted_pcts, "%"))
avg_data$strategy <- factor(avg_data$strategy,
                             levels = intersect(strat_order, unique(avg_data$strategy)))

# --- Plotting function for standard metrics ---
metric_plot <- function(data, y_col, show_legend = TRUE, show_y_title = TRUE) {
  y_info   <- y_axis_settings[[y_col]]
  y_title  <- if (show_y_title) y_info$title else NULL

  ggplot(data, aes(x = time, y = .data[[y_col]], color = strategy, group = strategy)) +
    geom_line(linewidth = line_size) +
    scale_color_manual(values = custom_colors, drop = FALSE) +
    labs(
      x = expression(bold("Rounds")),
      y = y_title
    ) +
    coord_cartesian(ylim = y_info$limits) +
    scale_y_continuous(breaks = y_info$breaks) +
    mytheme +
    theme(
      legend.position = if (show_legend) c(0.5, 0.75) else "none"
    ) +
    guides(color = guide_legend(ncol = 2))
}

# --- Plotting function for count metrics (h_blocked / h_division) ---
linear_log_trans <- scales::trans_new(
  name      = "linear_log",
  transform = function(x) ifelse(x <= 100, x / 100, 1 + log10(x / 100)),
  inverse   = function(y) ifelse(y <= 1,   y * 100, 100 * 10^(y - 1)),
  domain    = c(0, Inf)
)
log_only_breaks <- function(lim) {
  upper <- max(lim, na.rm = TRUE)
  if (!is.finite(upper) || upper <= 0) return(c(0))
  mag <- floor(log10(upper))
  log_breaks <- unique(as.integer(outer(c(1), 10^(0:mag))))
  sort(c(0, log_breaks[log_breaks > 10 & log_breaks <= upper]))
}
linear_log_breaks <- function(lim) {
  upper <- max(lim, na.rm = TRUE)
  if (!is.finite(upper) || upper <= 0) return(c(0, 25, 75))
  lin_breaks <- c(0, 25, 75, 150, 500, 1000)
  mag        <- floor(log10(upper))
  log_breaks <- unique(as.integer(outer(c(1), 10^(2:mag))))
  sort(unique(c(lin_breaks, log_breaks[log_breaks > 100 & log_breaks <= upper])))
}
fmt_count <- function(x) {
  dplyr::case_when(
    x >= 1e6 ~ paste0(x / 1e6, "M"),
    x >= 1e3 ~ paste0(x / 1e3, "K"),
    TRUE     ~ as.character(x)
  )
}

count_panel <- function(panel_data, y_col, y_lim, panel_title,
                        show_legend, show_y_title, y_breaks_fn = linear_log_breaks) {
  ggplot(panel_data, aes(x = time, y = .data[[y_col]], color = strategy, group = strategy)) +
    geom_line(linewidth = line_size) +
    scale_color_manual(values = custom_colors, drop = FALSE) +
    scale_y_continuous(
      trans  = linear_log_trans,
      limits = y_lim,
      breaks = y_breaks_fn(y_lim),
      labels = fmt_count
    ) +
    labs(
      x     = expression(bold("Rounds")),
      y     = if (show_y_title) "Count" else NULL,
      title = panel_title
    ) +
    mytheme +
    theme(
      legend.position = if (show_legend) c(0.5, 0.75) else "none",
      plot.title      = element_text(size = 12, face = "bold", hjust = 0.5)
    ) +
    guides(color = guide_legend(ncol = 2))
}

# --- PDF 1: h_dkl, h_f1, h_biasErr (all strategies) ---
y_columns <- c("h_dkl", "h_f1", "h_biasErr")

all_metric_plots <- list()
for (y_col in y_columns) {
  for (i in seq_along(faulty_pcts)) {
    f   <- faulty_pcts[i]
    sub <- avg_data %>% filter(f_pct == f)
    all_metric_plots <- c(all_metric_plots, list(metric_plot(
      sub,
      y_col        = y_col,
      show_legend  = (i == 1),
      show_y_title = (i == 1)
    )))
  }
}

dir.create("results", showWarnings = FALSE)
filename1 <- sprintf("results/h_metrics_trusted_budget_%gKB.pdf", budget)
pdf(filename1, width = width, height = height * length(y_columns))
grid.arrange(grobs = all_metric_plots, nrow = length(y_columns), ncol = length(faulty_pcts))
dev.off()
cat("Saved to:", filename1, "\n")

# --- PDF 2: h_blocked (BM only) and h_division (all BMDecay variants) ---
bm_data     <- avg_data %>% filter(strategy == "BM")
decay_strats <- c("BMDecay", paste0("BMDecay t=", trusted_pcts, "%"))
decay_data  <- avg_data %>% filter(strategy %in% decay_strats)

max_blocked   <- max(bm_data$h_blocked,    na.rm = TRUE)
max_divisions <- max(decay_data$h_division, na.rm = TRUE)
blocked_lim   <- c(0, if (is.finite(max_blocked))   max_blocked   * 1.05 else 100)
divisions_lim <- c(0, if (is.finite(max_divisions)) max_divisions * 1.05 else 100)

blocked_plots   <- list()
divisions_plots <- list()
for (i in seq_along(faulty_pcts)) {
  f <- faulty_pcts[i]

  blocked_plots[[i]] <- count_panel(
    bm_data %>% filter(f_pct == f),
    y_col        = "h_blocked",
    y_lim        = blocked_lim,
    panel_title  = sprintf("Blocked / BM — f=%d%%", f),
    show_legend  = (i == 1),
    show_y_title = (i == 1),
    y_breaks_fn  = log_only_breaks
  )
  divisions_plots[[i]] <- count_panel(
    decay_data %>% filter(f_pct == f),
    y_col        = "h_division",
    y_lim        = divisions_lim,
    panel_title  = sprintf("Divisions / BMDecay — f=%d%%", f),
    show_legend  = (i == 1),
    show_y_title = (i == 1),
    y_breaks_fn  = linear_log_breaks
  )
}

filename2 <- sprintf("results/h_blocked_division_trusted_budget_%gKB.pdf", budget)
pdf(filename2, width = width, height = height * 2)
grid.arrange(grobs = c(blocked_plots, divisions_plots), nrow = 2, ncol = length(faulty_pcts))
dev.off()
cat("Saved to:", filename2, "\n")
