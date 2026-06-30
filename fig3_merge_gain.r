#!/usr/bin/env Rscript
# Usage: Rscript fig3_merge_gain.r <budget> [zoom_from zoom_to]
#
# Generates two figures:
#
# fig3a — Summary: merge gain (%) vs. Byzantine proportion in system.
#         gain = (propByz_no_merge - propByz_merge) / propByz_no_merge × 100
#         Curves: t = 5 %, 10 %, 20 %
#
# fig3b — Evolution grid (1×4, one panel per faulty %):
#         Byzantine proportion in correct nodes' views vs. rounds.
#         Curves: t = 0 % (no merge), t = 5 %, t = 10 %, t = 20 %
#         Optional zoom window: zoom_from / zoom_to (finer time_step = 5).

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1) { cat("Usage: Rscript fig3_merge_gain.r <budget> [zoom_from zoom_to]\n"); quit(status = 1) }

library(ggplot2)
library(dplyr)
library(gridExtra)
library(gtable)

# ── Paramètres ────────────────────────────────────────────────────────────────
budget        <- as.numeric(args[1])
zoom_from     <- if (length(args) >= 2) as.integer(args[2]) else 0L
zoom_to       <- if (length(args) >= 3) as.integer(args[3]) else 0L
zoomed        <- zoom_from > 0

source("params.r")
trusted_pcts  <- c(5, 10, 20, 30)
conv_start    <- 11000

time_step <- 5 #if (zoomed) 5 else 100
line_size <- 0.4
width  <- 3.5


# ── Palette (cohérente avec les autres scripts) ───────────────────────────────
# Gain figure (t = 5/10/20% only)
merge_colors <- c(
  "t = 5%"  = "#E69F00",
  "t = 10%" = "#56B4E9",
  "t = 20%" = "#009E73",
  "t = 30%" = "#CC79A7"
)
merge_shapes <- c(
  "t = 5%"  = 16,
  "t = 10%" = 17,
  "t = 20%" = 15,
  "t = 30%" = 18
)
merge_lty <- c(
  "t = 5%"  = "solid",
  "t = 10%" = "solid",
  "t = 20%" = "solid",
  "t = 30%" = "solid"
)
level_order <- paste0("t = ", trusted_pcts, "%")

# Evolution figure (t = 0/5/10/20/30%)
trusted_pcts_evo  <- c(0, 5, 10, 20, 30)
level_order_evo   <- paste0("t = ", trusted_pcts_evo, "%")
evo_colors <- c(
  "t = 0%"  = "#000000",
  "t = 5%"  = "#E69F00",
  "t = 10%" = "#56B4E9",
  "t = 20%" = "#009E73",
  "t = 30%" = "#CC79A7"
)
evo_lty <- c(
  "t = 0%"  = "solid",
  "t = 5%"  = "solid",
  "t = 10%" = "solid",
  "t = 20%" = "solid",
  "t = 30%" = "solid"
)

# ══════════════════════════════════════════════════════════════════════════════
# fig3a — Gain summary
# ══════════════════════════════════════════════════════════════════════════════

read_conv <- function(fname) {
  if (!file.exists(fname)) {
    cat("Warning: fichier absent:", fname, "\n")
    return(NA_real_)
  }
  d <- read.table(fname, header = TRUE)
  d <- d[d$time > conv_start, "avgByzN", drop = FALSE]
  if (nrow(d) == 0) return(NA_real_)
  mean(d$avgByzN) / view
}

load_gain <- function() {
  rows <- list()
  for (f_pct in faulty_pcts) {
    f <- as.integer(nodes * f_pct / 100)
    base_vals <- numeric(nruns)
    for (run in 1:nruns) {
      fn             <- file.path(results_dir, sprintf("decay2-N%d-v%d-f%d-y%g-run%d", nodes, view, f, budget, run))
      base_vals[run] <- read_conv(fn)
    }
    base_conv <- mean(base_vals, na.rm = TRUE)
    for (t_pct in trusted_pcts) {
      t <- as.integer(nodes * t_pct / 100)
      merge_vals <- numeric(nruns)
      for (run in 1:nruns) {
        fn              <- file.path(results_dir, sprintf("decay2-N%d-v%d-f%d-y%g-x%d-run%d", nodes, view, f, budget, t, run))
        merge_vals[run] <- read_conv(fn)
      }
      merge_conv <- mean(merge_vals, na.rm = TRUE)
      cat(sprintf("f = %d%%, t = %d%%: diff= %.4f %%\n", f_pct, t_pct, (base_conv - merge_conv) * 100))
      rows[[length(rows) + 1]] <- data.frame(
        strategy = paste0("t = ", t_pct, "%"),
        f_pct    = f_pct,
        gain     = (base_conv - merge_conv) / base_conv
      )
    }
  }
  do.call(rbind, rows)
}

gain_df <- load_gain()

if (nrow(gain_df) == 0 || all(is.na(gain_df$gain))) {
  cat("Aucune donnée valide.\n"); quit(status = 1)
}
present <- intersect(level_order, unique(gain_df$strategy))
gain_df$strategy  <- factor(gain_df$strategy, levels = present)
gain_df$gain_pct  <- gain_df$gain * 100

max_y <- 10 # max(gain_df$gain_pct, na.rm = TRUE)
min_y <- round(min(gain_df$gain_pct, na.rm = TRUE), digits = 0) - 1
p_gain <- ggplot(gain_df, aes(x = f_pct / 100, y = gain_pct,
                               color = strategy, shape = strategy, linetype = strategy,
                               group = strategy)) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "gray50", linewidth = 0.5) +
  geom_line(linewidth = 0.5) +
  geom_point(size = 2.0) +
  scale_color_manual(values = merge_colors,  drop = FALSE) +
  scale_shape_manual(values = merge_shapes,  drop = FALSE) +
  scale_linetype_manual(values = merge_lty,  drop = FALSE) +
  coord_cartesian(ylim = c(min_y, max_y)) +
  scale_x_continuous(
    breaks       = faulty_pcts / 100,
    minor_breaks = NULL,
    sec.axis     = dup_axis(labels = NULL, name = NULL)
  ) +
  scale_y_continuous(
    breaks       = seq(min_y, max_y, by = 2),
    minor_breaks = seq(min_y, max_y, by = 1),
    sec.axis     = dup_axis(labels = NULL, name = NULL)
  ) +
  labs(
    x = expression(bold("Proportion of Byzantine nodes")),
    y = expression(bold("Byz. prop. gain (%)"))
  ) +
  mytheme +
  theme(legend.position = c(0.2, 0.80)) +
  guides(color    = guide_legend(ncol = 1),
         linetype = guide_legend(ncol = 1),
         shape    = guide_legend(ncol = 1))

dir.create("results", showWarnings = FALSE)
out_a <- sprintf("results/fig3a_merge_gain_%gKB.pdf", budget)
pdf(out_a, width = width, height = height)
print(p_gain)
dev.off()
cat("Saved:", out_a, "\n")

# ══════════════════════════════════════════════════════════════════════════════
# fig3b — Evolution grid (1×4)
# ══════════════════════════════════════════════════════════════════════════════

size <- 16
mytheme2 <- theme(
  panel.grid.major        = element_line(color = "gray90",  linewidth = 0.50),
  panel.grid.minor        = element_line(color = "gray95",  linewidth = 0.25),
  panel.background        = element_rect(fill = "white"),
  plot.background         = element_rect(fill = "white"),
  panel.border            = element_rect(colour = "black", linewidth = 1, fill = NA),
  legend.spacing.y        = unit(0.005, "cm"),
  text                    = element_text(size = size, color = "black"),
  axis.title.x            = element_text(size = size, face = "bold"),
  axis.title.y            = element_text(size = size, face = "bold"),
  axis.text.x             = element_text(size = size, face = "bold"),
  axis.text.y             = element_text(size = size, face = "bold"),
  plot.title              = element_text(size = size, face = "bold"),
  legend.text             = element_text(size = size, face = "bold"),
  legend.title            = element_blank(),
  legend.background       = element_rect(fill = "transparent", colour = NA),
  legend.box.background   = element_rect(fill = "transparent", colour = NA),
  legend.key.height       = unit(9,  "pt"),
  legend.key.width        = unit(15, "pt"),
  plot.margin             = margin(5.5, 0, 5.5, 0, "pt"),
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

read_evo <- function(fname, t_pct, f_pct, run) {
  if (!file.exists(fname)) {
    cat("Warning: fichier absent:", fname, "\n")
    return(NULL)
  }
  d <- read.table(fname, header = TRUE)
  d <- d[, c("time", "avgByzN"), drop = FALSE]
  d$time    <- as.integer(d$time)
  d$t_label <- paste0("t = ", t_pct, "%")
  d$f_pct   <- f_pct
  d$run     <- run
  if (zoomed) d <- d[d$time >= zoom_from & d$time <= zoom_to, ]
  d
}

load_evolution <- function() {
  df <- data.frame()
  for (f_pct in faulty_pcts) {
    f <- as.integer(nodes * f_pct / 100)
    for (t_pct in trusted_pcts_evo) {
      for (run in 1:nruns) {
        fn <- if (t_pct == 0L) {
          file.path(results_dir, sprintf("decay2-N%d-v%d-f%d-y%g-run%d", nodes, view, f, budget, run))
        } else {
          t <- as.integer(nodes * t_pct / 100)
          file.path(results_dir, sprintf("decay2-N%d-v%d-f%d-y%g-x%d-run%d", nodes, view, f, budget, t, run))
        }
        d <- read_evo(fn, t_pct, f_pct, run)
        if (!is.null(d)) df <- rbind(df, d)
      }
    }
  }
  df
}

prepare_evo <- function(df) {
  df$propByz <- df$avgByzN / view
  avg <- df %>%
    group_by(t_label, f_pct, time) %>%
    summarise(propByz = mean(propByz), .groups = "drop") %>%
    filter(time %% time_step == 0)
  present_evo <- intersect(level_order_evo, unique(avg$t_label))
  avg$t_label <- factor(avg$t_label, levels = present_evo)
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
                   color = t_label, linetype = t_label, group = t_label)) +
    geom_hline(yintercept = optimal, linetype = "dashed",
               color = "gray50", linewidth = 0.5) +
    geom_vline(xintercept = 10000, linetype = "dotted",
               color = "gray50", linewidth = 0.5) +
    geom_line(linewidth = line_size) +
    scale_color_manual(values = evo_colors,  drop = FALSE) +
    scale_linetype_manual(values = evo_lty,  drop = FALSE) +
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
    mytheme2 +
    theme(
      legend.position = if (show_legend) c(0.55, 0.70) else "none",
      axis.text.y     = if (show_y_axis) NULL else element_blank(),
      axis.ticks.y    = if (show_y_axis) NULL else element_blank()
    ) +
    guides(color    = guide_legend(ncol = 1),
           linetype = guide_legend(ncol = 1))
}

raw_evo <- load_evolution()
if (nrow(raw_evo) == 0) {
  cat("Warning: no evolution data found, skipping fig3b.\n")
} else {
  avg_evo <- prepare_evo(raw_evo)

  plots <- vector("list", length(faulty_pcts))
  for (i in seq_along(faulty_pcts)) {
    f   <- faulty_pcts[i]
    sub <- avg_evo %>% filter(f_pct == f)
    plots[[i]] <- byz_plot(sub, f,
                            show_legend  = (i == 1),
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
  out_b    <- sprintf("results/fig3b_evolution_merge_%gKB%s.pdf", budget, zoom_tag)
  pdf(out_b, width = 10, height = height)
  grid::grid.draw(combined)
  dev.off()
  cat("Saved:", out_b, "\n")
}

# ══════════════════════════════════════════════════════════════════════════════
# fig3c — Gain at peak attack round
# ══════════════════════════════════════════════════════════════════════════════
# For each f_pct: find the round where avgByzN is maximal in the no-merge
# curve, then compute gain = (propByz_no_merge - propByz_merge) /
# propByz_no_merge at that round.

load_peak_gain <- function() {
  rows <- list()
  for (f_pct in faulty_pcts) {
    f <- as.integer(nodes * f_pct / 100)

    # -- load no-merge runs and average them
    base_list <- lapply(1:nruns, function(run) {
      fn <- file.path(results_dir, sprintf("decay2-N%d-v%d-f%d-y%g-run%d", nodes, view, f, budget, run))
      if (!file.exists(fn)) { cat("Warning: absent:", fn, "\n"); return(NULL) }
      d <- read.table(fn, header = TRUE)
      d[, c("time", "avgByzN")]
    })
    base_list <- Filter(Negate(is.null), base_list)
    if (length(base_list) == 0) next

    base_avg <- do.call(rbind, base_list) %>%
      group_by(time) %>%
      summarise(avgByzN = mean(avgByzN), .groups = "drop")

    # find peak round (max avgByzN in no-merge curve)
    peak_row   <- base_avg[which.max(base_avg$avgByzN), ]
    peak_round <- peak_row$time
    peak_byz   <- peak_row$avgByzN / view

    for (t_pct in trusted_pcts) {
      t <- as.integer(nodes * t_pct / 100)
      merge_at_peak <- numeric(nruns)
      for (run in 1:nruns) {
        fn <- file.path(results_dir, sprintf("decay2-N%d-v%d-f%d-y%g-x%d-run%d", nodes, view, f, budget, t, run))
        if (!file.exists(fn)) { cat("Warning: absent:", fn, "\n"); merge_at_peak[run] <- NA; next }
        d <- read.table(fn, header = TRUE)
        row <- d[d$time == peak_round, "avgByzN"]
        merge_at_peak[run] <- if (length(row) == 1) row / view else NA_real_
      }
      merge_conv <- mean(merge_at_peak, na.rm = TRUE)
      gain_val   <- if (!is.na(peak_byz) && peak_byz > 0) (peak_byz - merge_conv) / peak_byz * 100 else NA_real_
      rows[[length(rows) + 1]] <- data.frame(
        strategy    = paste0("t = ", t_pct, "%"),
        f_pct       = f_pct,
        peak_round  = peak_round,
        gain_pct    = gain_val
      )
    }
  }
  do.call(rbind, rows)
}

peak_gain_df <- load_peak_gain()

if (!is.null(peak_gain_df) && nrow(peak_gain_df) > 0 && !all(is.na(peak_gain_df$gain_pct))) {
  present_pg <- intersect(level_order, unique(peak_gain_df$strategy))
  peak_gain_df$strategy <- factor(peak_gain_df$strategy, levels = present_pg)

  max_y_c <- ceiling(max(peak_gain_df$gain_pct, na.rm = TRUE) / 5) * 5
  min_y_c <- floor(min(peak_gain_df$gain_pct,   na.rm = TRUE) / 5) * 5

  p_peak <- ggplot(peak_gain_df, aes(x = f_pct / 100, y = gain_pct,
                                      color = strategy, shape = strategy, linetype = strategy,
                                      group = strategy)) +
    geom_hline(yintercept = 0, linetype = "dashed", color = "gray50", linewidth = 0.5) +
    geom_line(linewidth = 0.5) +
    geom_point(size = 2.0) +
    scale_color_manual(values = merge_colors, drop = FALSE) +
    scale_shape_manual(values = merge_shapes, drop = FALSE) +
    scale_linetype_manual(values = merge_lty,  drop = FALSE) +
    coord_cartesian(ylim = c(min_y_c, max_y_c)) +
    scale_x_continuous(
      breaks       = faulty_pcts / 100,
      minor_breaks = NULL,
      sec.axis     = dup_axis(labels = NULL, name = NULL)
    ) +
    scale_y_continuous(
      breaks       = seq(min_y_c, max_y_c, by = 5),
      minor_breaks = seq(min_y_c, max_y_c, by = 1),
      sec.axis     = dup_axis(labels = NULL, name = NULL)
    ) +
    labs(
      x = expression(bold("Proportion of Byzantine nodes")),
      y = expression(bold("Byz. prop. gain at peak (%)"))
    ) +
    mytheme +
    theme(legend.position = "none") +
    guides(color    = guide_legend(ncol = 1),
           linetype = guide_legend(ncol = 1),
           shape    = guide_legend(ncol = 1))

  out_c <- sprintf("results/fig3c_peak_gain_%gKB.pdf", budget)
  pdf(out_c, width = width, height = height)
  print(p_peak)
  dev.off()
  cat("Saved:", out_c, "\n")
} else {
  cat("Warning: no peak-gain data, skipping fig3c.\n")
}
