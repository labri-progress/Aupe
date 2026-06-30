#!/usr/bin/env Rscript
# Usage: Rscript fig7_baselines.r <budget> [zoom_from zoom_to]
#
# Generates three figures:
#
# fig7a — Evolution grid (1×4, one panel per faulty %):
#         Byzantine proportion in correct nodes' views (avgByzN/view) vs. rounds.
#         Strategies: Aupe, Brahms, Basalt.
#         Optional zoom window: zoom_from / zoom_to (finer time_step = 5).
#
# fig7b — Summary at convergence (mean over rounds > 11000) vs. Byzantine
#         proportion in the system.
#         Strategies: Aupe, Brahms, Basalt.
#
# fig7c — Same summary with Aupe BMDecay (decay2, no merge) added.

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1) { cat("Usage: Rscript fig7_baselines.r <budget> [zoom_from zoom_to]\n"); quit(status = 1) }

library(ggplot2)
library(dplyr)
library(gridExtra)
library(gtable)

# ── Paramètres ────────────────────────────────────────────────────────────────
budget    <- as.numeric(args[1])
zoom_from <- if (length(args) >= 2) as.integer(args[2]) else 0L
zoom_to   <- if (length(args) >= 3) as.integer(args[3]) else 0L
zoomed    <- zoom_from > 0

source("params.r")
conv_start  <- 11000

time_step <- 5 #if (zoomed) 5 else 100
line_size <- 0.4



# ── Palette (Okabe-Ito, cohérente avec les autres scripts) ────────────────────
custom_colors <- c(
  "Aupe"        = "#56B4E9",   # bleu ciel   (cohérent avec fig1)
  "Basalt"       = "#E69F00",   # orange      (cohérent avec fig2)
  "Brahms"       = "#D55E00",   # vermillion  (cohérent avec fig2)
  "BMDecay" = "#000000"    # noir        (cohérent avec fig1, fig2)
)
custom_lty <- c(
  "Aupe"        = "solid",
  "Basalt"       = "solid",
  "Brahms"       = "solid",
  "BMDecay" = "solid"
)
custom_shapes <- c(
  "Aupe"        = 18,
  "Basalt"       = 16,
  "Brahms"       = 17,
  "BMDecay" = 15
)

level_order_abc  <- c("Aupe", "Basalt", "Brahms")
level_order_abcd <- c("Aupe", "Basalt", "Brahms", "BMDecay")

# ══════════════════════════════════════════════════════════════════════════════
# fig7a — Evolution grid (1×4)
# ═══════════════════════════════════════════════════════════════════════════════════════════════════════

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
      fn <- file.path(results_dir, sprintf("array-N%d-v%d-f%d-run%d",  nodes, view, f, run))
      d  <- read_evo(fn, "Aupe",  f_pct, run)
      if (!is.null(d)) df <- rbind(df, d)

      fn <- file.path(results_dir, sprintf("brahms-N%d-v%d-f%d-run%d", nodes, view, f, run))
      d  <- read_evo(fn, "Brahms", f_pct, run)
      if (!is.null(d)) df <- rbind(df, d)

      fn <- file.path(results_dir, sprintf("basalt-N%d-v%d-f%d-run%d", nodes, view, f, run))
      d  <- read_evo(fn, "Basalt", f_pct, run)
      if (!is.null(d)) df <- rbind(df, d)
    }
  }
  df
}

prepare_evo <- function(df, level_order) {
  df$propByz <- df$avgByzN / view
  avg <- df %>%
    group_by(strategy, f_pct, time) %>%
    summarise(propByz = mean(propByz), .groups = "drop") %>%
    filter(time %% time_step == 0)
  present <- intersect(level_order, unique(avg$strategy))
  avg$strategy <- factor(avg$strategy, levels = present)
  avg
}

if (zoomed) {
  x_breaks <- pretty(c(zoom_from, zoom_to), n = 3)
  x_labels <- as.character(x_breaks)
} else {
  x_breaks <- c(0, 5000, 10000, 15000, 20000)
  x_labels <- c("0", "5K", "10K", "15K", "20K")
}

byz_plot <- function(data, f, show_legend = FALSE, show_y_title = TRUE, show_y_axis = TRUE, legend_pos = c(0.5, 0.20)) {
  optimal <- f / 100
  ggplot(data, aes(x = time, y = propByz,
                   color = strategy, linetype = strategy, group = strategy)) +
    geom_hline(yintercept = optimal, linetype = "dashed",
               color = "gray50", linewidth = 0.5) +
    geom_vline(xintercept = 10000, linetype = "dotted",
               color = "gray50", linewidth = 0.5) +
    geom_line(linewidth = line_size) +
    scale_color_manual(values = custom_colors, drop = FALSE) +
    scale_linetype_manual(values = custom_lty,  drop = FALSE) +
    labs(
      x = expression(bold("Rounds")),
      y = if (show_y_title) expression(bold("Prop. of Byz. samp.")) else NULL,
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
      legend.position = if (show_legend) legend_pos else "none",
      axis.text.y     = if (show_y_axis) NULL else element_blank(),
      axis.ticks.y    = if (show_y_axis) NULL else element_blank()
    ) +
    guides(color    = guide_legend(ncol = 1),
           linetype = guide_legend(ncol = 1))
}

raw_evo <- load_evolution()
if (nrow(raw_evo) == 0) {
  cat("Warning: no evolution data found, skipping fig7a.\n")
} else {
  avg_evo <- prepare_evo(raw_evo, level_order_abc)

  plots <- vector("list", length(faulty_pcts))
  for (i in seq_along(faulty_pcts)) {
    f   <- faulty_pcts[i]
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

  dir.create("results", showWarnings = FALSE)
  zoom_tag <- if (zoomed) sprintf("-zoom%d-%d", zoom_from, zoom_to) else ""
  out_a    <- sprintf("results/fig7a_evolution_baselines%s.pdf", zoom_tag)
  pdf(out_a, width = 7, height = height)
  grid::grid.draw(combined)
  dev.off()
  cat("Saved:", out_a, "\n")
}

# ══════════════════════════════════════════════════════════════════════════════
# fig7a_f20 — Evolution single panel, f = 20 % only
# ══════════════════════════════════════════════════════════════════════════════

if (nrow(raw_evo) == 0) {
  cat("Warning: no evolution data found, skipping fig7a_f20.\n")
} else {
  sub_f20 <- avg_evo %>% filter(f_pct == 20)
  zoom_tag <- if (zoomed) sprintf("-zoom%d-%d", zoom_from, zoom_to) else ""
  out_a20  <- sprintf("results/fig7a_f20_evolution_baselines%s.pdf", zoom_tag)
  pdf(out_a20, width = 3, height = height)
  print(byz_plot(sub_f20, f = 20, show_legend = TRUE, show_y_title = TRUE, legend_pos = c(0.5, 0.35)))
  dev.off()
  cat("Saved:", out_a20, "\n")
}

# ══════════════════════════════════════════════════════════════════════════════
# fig7b / fig7c — Convergence summary
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

load_convergence <- function(with_decay2 = FALSE) {
  df <- data.frame()
  for (f_pct in faulty_pcts) {
    f <- as.integer(nodes * f_pct / 100)
    for (run in 1:nruns) {
      fn <- file.path(results_dir, sprintf("array-N%d-v%d-f%d-run%d",  nodes, view, f, run))
      d  <- read_convergence(fn, "Aupe",  f_pct)
      if (!is.null(d)) df <- rbind(df, d)

      fn <- file.path(results_dir, sprintf("brahms-N%d-v%d-f%d-run%d", nodes, view, f, run))
      d  <- read_convergence(fn, "Brahms", f_pct)
      if (!is.null(d)) df <- rbind(df, d)

      fn <- file.path(results_dir, sprintf("basalt-N%d-v%d-f%d-run%d", nodes, view, f, run))
      d  <- read_convergence(fn, "Basalt", f_pct)
      if (!is.null(d)) df <- rbind(df, d)

      if (with_decay2) {
        fn <- file.path(results_dir, sprintf("decay2-N%d-v%d-f%d-y%g-run%d", nodes, view, f, budget, run))
        d  <- read_convergence(fn, "BMDecay", f_pct)
        if (!is.null(d)) df <- rbind(df, d)
      }
    }
  }
  df
}

conv_plot <- function(avg_conv, level_order, legend_pos = c(0.6, 0.1)) {
  present <- intersect(level_order, unique(avg_conv$strategy))
  avg_conv$strategy <- factor(avg_conv$strategy, levels = present)

  ref_df <- data.frame(f_pct = faulty_pcts, ref = faulty_pcts / 100)

  ggplot(avg_conv, aes(x = f_pct / 100, y = propByz,
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
      breaks       = faulty_pcts / 100,
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
      x = expression(bold("Proportion of Byzantine nodes")),
      y = expression(bold("Prop. of Byz. samp."))
    ) +
    mytheme +
    theme(legend.position = "none") + #legend_pos) +
    guides(color    = guide_legend(ncol = 2),
           linetype = guide_legend(ncol = 2),
           shape    = guide_legend(ncol = 2))
}

dir.create("results", showWarnings = FALSE)

# fig7b — Aupe, Basalt, Brahms
raw_conv_b <- load_convergence(with_decay2 = FALSE)
if (nrow(raw_conv_b) == 0) {
  cat("Warning: no convergence data, skipping fig7b.\n")
} else {
  avg_conv_b <- raw_conv_b %>%
    group_by(strategy, f_pct) %>%
    summarise(propByz = mean(propByz), .groups = "drop")

  out_b <- "results/fig7b_convergence_baselines.pdf"
  pdf(out_b, width = 3, height = 2.5)
  print(conv_plot(avg_conv_b, level_order_abc))
  dev.off()
  cat("Saved:", out_b, "\n")
}

# fig7c — Aupe, Basalt, Brahms + Aupe BMDecay
raw_conv_c <- load_convergence(with_decay2 = TRUE)
if (nrow(raw_conv_c) == 0) {
  cat("Warning: no convergence data for fig7c.\n")
} else {
  avg_conv_c <- raw_conv_c %>%
    group_by(strategy, f_pct) %>%
    summarise(propByz = mean(propByz), .groups = "drop")

  out_c <- sprintf("results/fig7c_convergence_with_decay2_%gKB.pdf", budget)
  pdf(out_c, width = 3, height = height)
  print(conv_plot(avg_conv_c, level_order_abcd))
  dev.off()
  cat("Saved:", out_c, "\n")
}
