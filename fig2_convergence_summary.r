#!/usr/bin/env Rscript
# Usage: Rscript fig2_convergence_summary.r <budget> [zoom_from zoom_to]
#
# Generates two figures:
#
# fig2a — Summary: Byzantine proportion in correct nodes' views at convergence
#         (mean over rounds > 11000) vs. Byzantine proportion in system.
#         Strategies: Basalt / Brahms / Aupe BMDecay
#         Reference dashed line: y = f/N (unfiltered view).
#
# fig2b — Evolution grid (1x4, one panel per faulty %):
#         Byzantine proportion in correct nodes' views vs. rounds.
#         Same three strategies, same colour palette.
#         Optional zoom window: zoom_from / zoom_to (finer time_step = 5).

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1) { cat("Usage: Rscript fig2_convergence_summary.r <budget> [zoom_from zoom_to]\n"); quit(status = 1) }

library(ggplot2)
library(dplyr)
library(gridExtra)
library(gtable)


# ── Paramètres ────────────────────────────────────────────────────────────────
budget      <- as.numeric(args[1])
zoom_from   <- if (length(args) >= 2) as.integer(args[2]) else 0L
zoom_to     <- if (length(args) >= 3) as.integer(args[3]) else 0L
zoomed      <- zoom_from > 0

source("params.r")
nruns       <- 4
conv_start  <- 11000

time_step <- 5 #if (zoomed) 5 else 100
line_size <- 0.4

faulty_pcts <- c(10, 14, 18, 20, 24, 28, 30, 34, 38, 40)
f_breaks    <- c(10, 20, 30, 40)
# ── Palette (Okabe-Ito, cohérente avec les autres scripts) ────────────────────
custom_colors <- c(
  "Basalt"       = "#E69F00",   # orange
  "Brahms"       = "#D55E00",   # vermillion
  "BMDecay" = "#000000"    # noir
)
custom_lty <- c(
  "Basalt"       = "solid",
  "Brahms"       = "solid",
  "BMDecay" = "solid"
)
custom_shapes <- c(
  "Basalt"       = 16,
  "Brahms"       = 17,
  "BMDecay" = 15
)
level_order <- c("BMDecay", "Basalt", "Brahms")

# ══════════════════════════════════════════════════════════════════════════════
# fig2a — Convergence summary
# ══════════════════════════════════════════════════════════════════════════════

read_convergence <- function(fname, label, f_pct) {
  if (!file.exists(fname)) {
    cat("Warning: fichier absent:", fname, "\n")
    return(NULL)
  }
  d <- read.table(fname, header = TRUE)
  d <- d[d$time > conv_start, "avgByzN", drop = FALSE]
  if (nrow(d) == 0) {
    cat("Warning: aucune donnée après round", conv_start, "dans", fname, "\n")
    return(NULL)
  }
  data.frame(strategy = label, f_pct = f_pct, propByz = mean(d$avgByzN) / view)
}

load_convergence <- function() {
  df <- data.frame()
  for (f_pct in faulty_pcts) {
    f <- as.integer(nodes * f_pct / 100)
    for (run in 1:nruns) {
      fn <- file.path(results_dir, sprintf("basalt-N%d-v%d-f%d-run%d", nodes, view, f, run))
      d  <- read_convergence(fn, "Basalt", f_pct)
      if (!is.null(d)) df <- rbind(df, d)

      fn <- file.path(results_dir, sprintf("brahms-N%d-v%d-f%d-run%d", nodes, view, f, run))
      d  <- read_convergence(fn, "Brahms", f_pct)
      if (!is.null(d)) df <- rbind(df, d)

      fn <- file.path(results_dir, sprintf("decay2-N%d-v%d-f%d-y%g-run%d", nodes, view, f, budget, run))
      d  <- read_convergence(fn, "BMDecay", f_pct)
      if (!is.null(d)) df <- rbind(df, d)
    }
  }
  df
}

raw_conv <- load_convergence()
if (nrow(raw_conv) == 0) { cat("Aucune donnée chargée (convergence).\n"); quit(status = 1) }

avg_conv <- raw_conv %>%
  group_by(strategy, f_pct) %>%
  summarise(propByz = mean(propByz), .groups = "drop")

present      <- intersect(level_order, unique(avg_conv$strategy))
avg_conv$strategy <- factor(avg_conv$strategy, levels = present)

ref_df <- data.frame(f_pct = faulty_pcts, ref = faulty_pcts / 100)


p_summary <- ggplot(avg_conv, aes(x = f_pct / 100, y = propByz,
                                  color = strategy, shape = strategy,
                                  linetype = strategy, group = strategy)) +
  geom_line(data = ref_df, aes(x = f_pct / 100, y = ref),
            inherit.aes = FALSE,
            linetype = "dashed", color = "gray50", linewidth = 0.5) +
  geom_line(linewidth = 0.5) +
  geom_point(size = 2.0) +
  scale_color_manual(values = custom_colors,  drop = FALSE) +
  scale_linetype_manual(values = custom_lty,  drop = FALSE) +
  scale_shape_manual(values = custom_shapes,  drop = FALSE) +
  scale_x_continuous(
    breaks       = f_breaks / 100,
    minor_breaks = NULL,
    sec.axis     = dup_axis(labels = NULL, name = NULL)
  ) +
  scale_y_continuous(
    breaks       = seq(0, 1, by = 0.2),
    minor_breaks = seq(0, 1, by = 0.1),
    sec.axis     = dup_axis(labels = NULL, name = NULL)
  ) +
  coord_cartesian(ylim = c(0, 1)) +
  labs(
    x = expression(bold("Prop. of Byz. nodes")),
    y = expression(bold("Prop. of Byz. samp."))
  ) +
  mytheme +
  theme(legend.position = c(0.71, 0.15)) +
  guides(color    = guide_legend(ncol = 1),
         linetype = guide_legend(ncol = 1),
         shape    = guide_legend(ncol = 1))

dir.create("results", showWarnings = FALSE)
out_a <- sprintf("results/fig2a_convergence_summary_%gKB.pdf", budget)
pdf(out_a, width = 3, height = height)
print(p_summary)
dev.off()
cat("Saved:", out_a, "\n")

# ══════════════════════════════════════════════════════════════════════════════
# fig2b — Evolution grid (1×4)
# ══════════════════════════════════════════════════════════════════════════════

read_evo <- function(fname, label, f_pct, run) {
  if (!file.exists(fname)) {
    cat("Warning: fichier absent:", fname, "\n")
    return(NULL)
  }
  d <- read.table(fname, header = TRUE)
  d <- d[, c("time", "avgByzN"), drop = FALSE]
  d$time     <- as.integer(d$time)
  d$strategy <- label
  d$f_pct    <- f_pct
  d$run      <- run
  if (zoomed) d <- d[d$time >= zoom_from & d$time <= zoom_to, ]
  d
}

load_evolution <- function() {
  df <- data.frame()
  for (f_pct in faulty_pcts) {
    f <- as.integer(nodes * f_pct / 100)
    for (run in 1:nruns) {
      fn <- file.path(results_dir, sprintf("basalt-N%d-v%d-f%d-run%d", nodes, view, f, run))
      d  <- read_evo(fn, "Basalt", f_pct, run)
      if (!is.null(d)) df <- rbind(df, d)

      fn <- file.path(results_dir, sprintf("brahms-N%d-v%d-f%d-run%d", nodes, view, f, run))
      d  <- read_evo(fn, "Brahms", f_pct, run)
      if (!is.null(d)) df <- rbind(df, d)

      fn <- file.path(results_dir, sprintf("decay2-N%d-v%d-f%d-y%g-run%d", nodes, view, f, budget, run))
      d  <- read_evo(fn, "BMDecay", f_pct, run)
      if (!is.null(d)) df <- rbind(df, d)
    }
  }
  df
}

prepare_evo <- function(df) {
  df$propByz <- df$avgByzN / view
  avg <- df %>%
    group_by(strategy, f_pct, time) %>%
    summarise(propByz = mean(propByz), .groups = "drop") %>%
    filter(time %% time_step == 0)
  present_evo <- intersect(level_order, unique(avg$strategy))
  avg$strategy <- factor(avg$strategy, levels = present_evo)
  avg
}

if (zoomed) {
  x_breaks <- pretty(c(zoom_from, zoom_to), n = 4)
  x_labels <- as.character(x_breaks)
} else {
  x_breaks <- c(0, 5000, 10000, 15000, 20000)
  x_labels <- c("0", "5K", "10K", "15K", "20K")
}

byz_plot <- function(data, f, show_legend = FALSE, show_y_title = TRUE, show_y_axis = TRUE) {
  optimal <- f / 100
  ggplot(data, aes(x = time, y = propByz,
                   color = strategy, linetype = strategy, group = strategy)) +
    geom_hline(yintercept = optimal, linetype = "dashed",
               color = "gray50", linewidth = 0.5) +
    geom_vline(xintercept = 10000, linetype = "dotted",
               color = "gray50", linewidth = 0.5) +
    geom_line(linewidth = line_size) +
    scale_color_manual(values = custom_colors,  drop = FALSE) +
    scale_linetype_manual(values = custom_lty,  drop = FALSE) +
    labs(
      x     = expression(bold("Rounds")),
      y     = if (show_y_title) expression(bold("Prop. of Byz. samp.")) else NULL,
      #title = sprintf("f = %.2f", f / 100)
    ) +
    coord_cartesian(ylim = c(0, 1)) +
    scale_x_continuous(
      breaks   = x_breaks,
      labels   = x_labels,
      sec.axis = dup_axis(labels = NULL, name = NULL)
    ) +
    scale_y_continuous(
      breaks       = seq(0, 1, by = 0.2),
      minor_breaks = seq(0, 1, by = 0.1),
      sec.axis     = dup_axis(labels = NULL, name = NULL)
    ) +
    mytheme +
    theme(
      legend.position = if (show_legend) c(0.5, 0.20) else "none",
      axis.text.y     = if (show_y_axis) NULL else element_blank(),
      axis.ticks.y    = if (show_y_axis) NULL else element_blank()
    ) +
    guides(color    = guide_legend(ncol = 1),
           linetype = guide_legend(ncol = 1))
}

raw_evo <- load_evolution()
if (nrow(raw_evo) == 0) {
  cat("Warning: no evolution data found, skipping fig2b.\n")
} else {
  avg_evo <- prepare_evo(raw_evo)

  plots <- vector("list", length(f_breaks))
  for (i in seq_along(f_breaks)) {
    f   <- f_breaks[i]
    sub <- avg_evo %>% filter(f_pct == f)
    plots[[i]] <- byz_plot(sub, f,
                            show_legend  = (i == 4),
                            show_y_title = (i == 1),
                            show_y_axis  = (i == 1))
  }

  grobs_out  <- lapply(plots, ggplotGrob)
  panel_cols <- sapply(grobs_out, function(g) g$layout$l[g$layout$name == "panel"])
  common_w   <- do.call(grid::unit.pmax,
                        Map(function(g, col) g$widths[col], grobs_out, panel_cols))
  grobs_out  <- Map(function(g, col) { g$widths[col] <- common_w; g },
                    grobs_out, panel_cols)
  combined   <- Reduce(gtable_cbind, grobs_out)

  zoom_tag <- if (zoomed) sprintf("-zoom%d-%d", zoom_from, zoom_to) else ""
  out_b    <- sprintf("results/fig2b_evolution_strategies_%gKB%s.pdf", budget, zoom_tag)
  pdf(out_b, width = 10, height = height)
  grid::grid.draw(combined)
  dev.off()
  cat("Saved:", out_b, "\n")
}
