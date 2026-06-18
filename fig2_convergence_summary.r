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

# ── Paramètres ────────────────────────────────────────────────────────────────
budget      <- as.numeric(args[1])
zoom_from   <- if (length(args) >= 2) as.integer(args[2]) else 0L
zoom_to     <- if (length(args) >= 3) as.integer(args[3]) else 0L
zoomed      <- zoom_from > 0

nodes       <- 1000
view        <- 20
nruns       <- 1
faulty_pcts <- c(10, 20, 30, 40)
conv_start  <- 11000
results_dir <- "output_byz"

time_step <- if (zoomed) 5 else 100
line_size <- 0.4

# ── Thème ─────────────────────────────────────────────────────────────────────
mytheme <- theme(
  panel.grid.major        = element_line(color = "gray90",  linewidth = 0.50),
  panel.grid.minor        = element_line(color = "gray95",  linewidth = 0.25),
  panel.background        = element_rect(fill = "white"),
  plot.background         = element_rect(fill = "white"),
  panel.border            = element_rect(colour = "black", linewidth = 1, fill = NA),
  text                    = element_text(size = 9, color = "black"),
  axis.title.x            = element_text(size = 9, face = "bold"),
  axis.title.y            = element_text(size = 9, face = "bold"),
  axis.text.x             = element_text(size = 8, face = "bold"),
  axis.text.y             = element_text(size = 8, face = "bold"),
  plot.title              = element_text(size = 9, face = "bold"),
  legend.text             = element_text(size = 8, face = "bold"),
  legend.title            = element_blank(),
  legend.background       = element_rect(fill = "transparent", colour = NA),
  legend.box.background   = element_rect(fill = "transparent", colour = NA),
  legend.key.height       = unit(9,  "pt"),
  plot.margin             = margin(5.5, 2, 5.5, 2, "pt"),
  axis.ticks              = element_line(color = "black", linewidth = 1),
  axis.ticks.length       = unit(4, "pt"),
  axis.minor.ticks.length = unit(2, "pt")
) + theme(
  axis.ticks.x.top         = element_line(color = "black", linewidth = 1),
  axis.ticks.y.right       = element_line(color = "black", linewidth = 1),
  axis.minor.ticks.x.top   = element_line(color = "black", linewidth = 0.5),
  axis.minor.ticks.y.right  = element_line(color = "black", linewidth = 0.5),
  axis.text.x.top          = element_blank(),
  axis.text.y.right        = element_blank()
)

# ── Palette (Okabe-Ito, cohérente avec les autres scripts) ────────────────────
custom_colors <- c(
  "Basalt"       = "#E69F00",   # orange
  "Brahms"       = "#D55E00",   # vermillion
  "Aupe BMDecay" = "#000000"    # noir
)
custom_lty <- c(
  "Basalt"       = "solid",
  "Brahms"       = "solid",
  "Aupe BMDecay" = "solid"
)
custom_shapes <- c(
  "Basalt"       = 16,
  "Brahms"       = 17,
  "Aupe BMDecay" = 15
)
level_order <- c("Aupe BMDecay", "Basalt", "Brahms")

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
      d  <- read_convergence(fn, "Aupe BMDecay", f_pct)
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
  theme(legend.position = c(0.23, 0.88)) +
  guides(color    = guide_legend(ncol = 1),
         linetype = guide_legend(ncol = 1),
         shape    = guide_legend(ncol = 1))

dir.create("results", showWarnings = FALSE)
out_a <- sprintf("results/fig2a_convergence_summary_%gKB.pdf", budget)
pdf(out_a, width = 3.5, height = 2.8)
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
      d  <- read_evo(fn, "Aupe BMDecay", f_pct, run)
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
  x_breaks <- pretty(c(zoom_from, zoom_to), n = 6)
  x_labels <- as.character(x_breaks)
} else {
  x_breaks <- c(0, 5000, 10000, 15000, 20000)
  x_labels <- c("0", "5K", "10K", "15K", "20K")
}

byz_plot <- function(data, f, show_legend = FALSE, show_y_title = TRUE) {
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
    theme(legend.position = if (show_legend) c(0.5, 0.80) else "none") +
    guides(color    = guide_legend(ncol = 1),
           linetype = guide_legend(ncol = 1))
}

raw_evo <- load_evolution()
if (nrow(raw_evo) == 0) {
  cat("Warning: no evolution data found, skipping fig2b.\n")
} else {
  avg_evo <- prepare_evo(raw_evo)

  plots <- vector("list", length(faulty_pcts))
  for (i in seq_along(faulty_pcts)) {
    f   <- faulty_pcts[i]
    sub <- avg_evo %>% filter(f_pct == f)
    plots[[i]] <- byz_plot(sub, f,
                            show_legend  = (i == 1),
                            show_y_title = (i == 1))
  }

  grobs_out <- lapply(plots, ggplotGrob)
  max_w     <- do.call(grid::unit.pmax, lapply(grobs_out, `[[`, "widths"))
  grobs_out <- lapply(grobs_out, function(g) { g$widths <- max_w; g })

  zoom_tag <- if (zoomed) sprintf("-zoom%d-%d", zoom_from, zoom_to) else ""
  out_b    <- sprintf("results/fig2b_evolution_strategies_%gKB%s.pdf", budget, zoom_tag)
  pdf(out_b, width = 7, height = 2.5)
  grid.arrange(grobs = grobs_out, nrow = 1, ncol = 4)
  dev.off()
  cat("Saved:", out_b, "\n")
}
