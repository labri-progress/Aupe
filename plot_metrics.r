#!/usr/bin/env Rscript
# Usage: Rscript plot_metrics.r <budget>
# Example: Rscript plot_metrics.r 1
#   Produces PDFs with metric plots (h_dkl, h_f1, h_biasErr, h_division/h_blocked)
#   grouped by faulty percentage (f=10,20,30) for the given budget.

args <- commandArgs(trailingOnly = TRUE)

library(ggplot2)
library(dplyr)
library(gridExtra)

# --- Parameters ---
budget       <- as.numeric(args[1])  # e.g. 0.5, 1, 2 (KB)
nodes        <- 1000
view         <- 20
nruns        <- 1
faulty_pcts  <- c(10, 20, 30)
strategies   <- c("bm", "decay", "array")
strat_labels <- c("bm" = "BM", "decay" = "BMDecay", "array" = "Array")
results_dir  <- "output_byz"

# --- Theme ---
line_size  <- 0.5
point_size <- 1.5
ratio      <- 3
width      <- 11
height     <- width / ratio

custom_colors <- c("BM" = "#882EE6", "BMDecay" = "#000000", "Array" = "#ff8833")

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

# --- Read and aggregate data ---
# h_dkl, h_f1, h_biasErr present in all strategies
# h_blocked only in bm; h_division only in decay
all_data <- data.frame()

for (strat in strategies) {
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
      if (!file.exists(fname)) {
        cat("Warning: file not found:", fname, "\n")
        next
      }
      d <- read.table(fname, header = TRUE)
      d$time     <- as.integer(d$time)
      d$strategy <- strat_labels[[strat]]
      d$f_pct    <- f_pct
      d$run      <- run

      # Ensure optional columns exist (fill with NA if absent)
      if (!"h_blocked"  %in% names(d)) d$h_blocked  <- NA_real_
      if (!"h_division" %in% names(d)) d$h_division <- NA_real_

      keep <- c("time", "strategy", "f_pct", "run",
                "h_dkl", "h_f1", "h_biasErr", "h_blocked", "h_division")
      all_data <- rbind(all_data, d[, keep])
    }
  }
}

# Average over runs
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

# --- Plotting function for standard metrics (all strategies) ---
metric_plot <- function(data, y_col, show_legend = TRUE, show_y_title = TRUE) {
  y_info   <- y_axis_settings[[y_col]]
  y_title  <- if (show_y_title) y_info$title else NULL
  y_limits <- y_info$limits
  y_breaks <- y_info$breaks

  p <- ggplot(data, aes(x = time, y = .data[[y_col]], color = strategy, group = strategy)) +
    geom_line(linewidth = line_size) +
    scale_color_manual(values = custom_colors) +
    #scale_x_log10(breaks = c(1e3, 5e3, 50e3, 100e3, 500e3),
      #            labels = c("1K", "5K", "50K", "100K", "500K")) +
    labs(
      x = expression(bold("Rounds")),
      y = y_title
    ) +
    coord_cartesian(ylim = y_limits) +
    scale_y_continuous(breaks = y_breaks) +
    mytheme +
    theme(
      legend.position = if (show_legend) c(0.5, 0.85) else "none"
    ) +
    guides(color = guide_legend(ncol = 1))

  return(p)
}

# --- Plotting function for h_blocked (BM) and h_division (BMDecay) ---
# Custom piecewise transformation: linear [0,100], log10 above 100
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
  lin_breaks  <- c(0, 25, 75, 150, 500, 1000)
  mag         <- floor(log10(upper))
  log_breaks  <- unique(as.integer(outer(c(1), 10^(2:mag))))
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
    scale_color_manual(values = custom_colors) +
    #scale_x_log10(breaks = c(1e3, 5e3, 50e3, 500e3),
                #  labels = c("1K", "5K", "50K", "500K")) +
    scale_y_continuous(
      trans   = linear_log_trans,
      limits  = y_lim,
      breaks  = y_breaks_fn(y_lim),
      labels  = fmt_count
    ) +
    labs(
      x     = expression(bold("Rounds")),
      y     = if (show_y_title) "Count" else NULL,
      title = panel_title
    ) +
    mytheme +
    theme(
      legend.position = if (show_legend) c(0.5, 0.85) else "none",
      plot.title      = element_text(size = 12, face = "bold", hjust = 0.5)
    ) +
    guides(color = guide_legend(ncol = 1))
}

# --- Build standard metric plots: 3 metrics x 3 faulty_pcts ---
y_columns <- c("h_dkl", "h_f1", "h_biasErr")

plots_by_metric <- list()
for (y_col in y_columns) {
  metric_plots <- list()
  for (i in seq_along(faulty_pcts)) {
    f   <- faulty_pcts[i]
    sub <- avg_data %>% filter(f_pct == f)
    metric_plots[[i]] <- metric_plot(
      sub,
      y_col        = y_col,
      show_legend  = (i == 1),
      show_y_title = (i == 1)
    )
  }
  plots_by_metric[[y_col]] <- metric_plots
}

all_metric_plots <- list()
for (y_col in y_columns) {
  all_metric_plots <- c(all_metric_plots, plots_by_metric[[y_col]])
}

dir.create("results", showWarnings = FALSE)
filename1 <- sprintf("results/h_dkl_f1_biasErr_budget_%gKB.pdf", budget)
pdf(filename1, width = width, height = height * length(y_columns))
grid.arrange(grobs = all_metric_plots, nrow = length(y_columns), ncol = length(faulty_pcts))
dev.off()
cat("Saved to:", filename1, "\n")

# --- Build h_blocked (BM) and h_division (BMDecay) plots ---
bm_data    <- avg_data %>% filter(strategy == "BM")
decay_data <- avg_data %>% filter(strategy == "BMDecay")

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
    show_legend  = FALSE,
    show_y_title = (i == 1),
    y_breaks_fn  = linear_log_breaks
  )
}

filename2 <- sprintf("results/h_blocked_division_budget_%gKB.pdf", budget)
pdf(filename2, width = width, height = height * 2)
grid.arrange(grobs = c(blocked_plots, divisions_plots), nrow = 2, ncol = length(faulty_pcts))
dev.off()
cat("Saved to:", filename2, "\n")
