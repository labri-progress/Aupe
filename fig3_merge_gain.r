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

# ── Paramètres ────────────────────────────────────────────────────────────────
budget        <- as.numeric(args[1])
zoom_from     <- if (length(args) >= 2) as.integer(args[2]) else 0L
zoom_to       <- if (length(args) >= 3) as.integer(args[3]) else 0L
zoomed        <- zoom_from > 0

nodes         <- 1000
view          <- 20
nruns         <- 1
faulty_pcts   <- c(10, 20, 30, 40)
trusted_pcts  <- c(5, 10, 20, 30)
conv_start    <- 11000
results_dir   <- "output_byz"

time_step <- if (zoomed) 5 else 100
line_size <- 0.4
width  <- 3.5
height <- 2.8

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

p_gain <- ggplot(gain_df, aes(x = f_pct / 100, y = gain_pct,
                               color = strategy, shape = strategy, linetype = strategy,
                               group = strategy)) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "gray50", linewidth = 0.5) +
  geom_line(linewidth = 0.5) +
  geom_point(size = 2.0) +
  scale_color_manual(values = merge_colors,  drop = FALSE) +
  scale_shape_manual(values = merge_shapes,  drop = FALSE) +
  scale_linetype_manual(values = merge_lty,  drop = FALSE) +
  coord_cartesian(ylim = c(0, 8)) +
  scale_x_continuous(
    breaks       = faulty_pcts / 100,
    minor_breaks = NULL,
    sec.axis     = dup_axis(labels = NULL, name = NULL)
  ) +
  scale_y_continuous(
    breaks       = seq(0, 8, by = 2),
    minor_breaks = seq(0, 8, by = 1),
    sec.axis     = dup_axis(labels = NULL, name = NULL)
  ) +
  labs(
    x = expression(bold("Proportion of Byzantine nodes")),
    y = expression(bold("Byz. prop. gain (%)"))
  ) +
  mytheme +
  theme(legend.position = c(0.17, 0.80)) +
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

byz_plot <- function(data, f, show_legend = FALSE, show_y_title = TRUE) {
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
      title = sprintf("f = %.2f", f / 100)
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
    theme(legend.position = if (show_legend) c(0.68, 0.80) else "none") +
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
                            show_y_title = (i == 1))
  }

  grobs_out <- lapply(plots, ggplotGrob)
  max_w     <- do.call(grid::unit.pmax, lapply(grobs_out, `[[`, "widths"))
  grobs_out <- lapply(grobs_out, function(g) { g$widths <- max_w; g })

  zoom_tag <- if (zoomed) sprintf("-zoom%d-%d", zoom_from, zoom_to) else ""
  out_b    <- sprintf("results/fig3b_evolution_merge_%gKB%s.pdf", budget, zoom_tag)
  pdf(out_b, width = 7, height = 2.5)
  grid.arrange(grobs = grobs_out, nrow = 1, ncol = 4)
  dev.off()
  cat("Saved:", out_b, "\n")
}
