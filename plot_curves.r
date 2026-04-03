#!/usr/bin/env Rscript
# Usage: Rscript plot_curves.r <budget> [<nruns>]
#
# Courbe 1 : Time series — BM, BMDecay, ER+Merge  (fixed f=30%, t=10%)
# Courbe 2 : Relative gain ER+Merge vs BMDecay    (steady state, bar chart)
# Courbe 3 : Recap — propByz in view vs propByz in system

args <- commandArgs(trailingOnly = TRUE)

library(ggplot2)
library(dplyr)
library(gridExtra)

# ─────────────────────────────────────────────────────────────
#  Parameters
# ─────────────────────────────────────────────────────────────
budget  <- as.numeric(args[1])
nruns   <- if (length(args) >= 2) as.integer(args[2]) else 1L

OUTDIR       <- "output_byz"
nodes        <- 1000
view         <- 20
ATTACK_START <- 10000
STEADY_LAST  <- 500          # rows from end for steady-state average

F_FRACS  <- c(10, 20, 30, 40)   # Byzantine fraction in system (%)
T_FRACS  <- c(5, 20)        # Trusted node fraction (%)
ER_VALS  <- c(0.5, 0.8)    # Eviction rates (decimal, as passed to -e)

C1_F <- 30    # reference Byzantine fraction for Courbe 1
C1_T <- 10    # reference trusted fraction for Courbe 1

METRIC <- "avgByzN"   # column used for propByz

# ─────────────────────────────────────────────────────────────
#  Theme  (identical to plot_three_figures.r)
# ─────────────────────────────────────────────────────────────
line_size  <- 0.5
point_size <- 2
ratio      <- 3.5
width      <- 12
height     <- width / ratio

mytheme <- theme(
  panel.grid.major      = element_line(color = "gray90", linewidth = 0.5),
  panel.grid.minor      = element_line(color = "gray95", linewidth = 0.25),
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
  axis.ticks            = element_line(color = "black", linewidth = 1),
  axis.ticks.length     = unit(4, "pt"),
  axis.minor.ticks.length = unit(2, "pt")
)
mytheme <- mytheme + guides() + theme(
  axis.ticks.x.top        = element_line(color = "black", linewidth = 1),
  axis.ticks.y.right      = element_line(color = "black", linewidth = 1),
  axis.minor.ticks.x.top  = element_line(color = "black", linewidth = 0.5),
  axis.minor.ticks.y.right = element_line(color = "black", linewidth = 0.5),
  axis.text.x.top         = element_blank(),
  axis.text.y.right       = element_blank()
)

# ─────────────────────────────────────────────────────────────
#  Colors & linetypes
# ─────────────────────────────────────────────────────────────
er_labels <- sprintf("ER=%.0f%%+Merge", ER_VALS * 100)

custom_colors <- c(
  "BM"      = "#882EE6",
  "BMDecay" = "#000000",
  setNames(c("#f4d03f", "#e67e22", "#c0392b"), er_labels)
)
custom_lty <- c(
  "BM"      = "solid",
  "BMDecay" = "dashed",
  setNames(rep("solid", length(er_labels)), er_labels)
)
custom_shape <- c(
  "BM"      = 15L,
  "BMDecay" = 17L,
  setNames(c(16L, 18L, 25L), er_labels)
)

er_bar_colors <- setNames(c("#f4d03f", "#e67e22", "#c0392b"),
                          sprintf("ER=%.0f%%", ER_VALS * 100))

# ─────────────────────────────────────────────────────────────
#  File-name builder  (matches run_experimentsK.sh convention)
# ─────────────────────────────────────────────────────────────
fname <- function(strat, f_count, t_count = 0, eviction_rate = 0.0, run = 1) {
  trusted_tag  <- if (t_count > 0)         sprintf("-x%d",  t_count)       else ""
  eviction_tag <- if (eviction_rate != 0.0) sprintf("-e%g", eviction_rate) else ""
  file.path(OUTDIR,
            sprintf("%s-N%d-v%d-f%d-y%g%s%s-run%d",
                    strat, nodes, view, f_count, budget,
                    trusted_tag, eviction_tag, run))
}

# ─────────────────────────────────────────────────────────────
#  Reader — averages over runs, keeps every row
# ─────────────────────────────────────────────────────────────
read_runs <- function(strat, f_count, t_count = 0, eviction_rate = 0.0,
                      strategy_label) {
  df <- data.frame()
  for (run in seq_len(nruns)) {
    f <- fname(strat, f_count, t_count, eviction_rate, run)
    if (!file.exists(f)) { cat("Warning: not found:", f, "\n"); next }
    d <- tryCatch(
      read.table(f, header = TRUE, fill = TRUE,
                 na.strings = c("NaN", "nan", "Inf", "-Inf", "inf")),
      error = function(e) { cat("Error reading", f, ":", conditionMessage(e), "\n"); NULL }
    )
    if (is.null(d) || !(METRIC %in% names(d))) next
    d$strategy <- strategy_label
    d$run      <- run
    df <- rbind(df, d[, intersect(c("time", METRIC, "strategy", "run"), names(d))])
  }
  df
}

# Steady-state proportion (mean of last STEADY_LAST rows, averaged across runs)
steady <- function(strat, f_count, t_count = 0, eviction_rate = 0.0) {
  df <- read_runs(strat, f_count, t_count, eviction_rate, "tmp")
  if (nrow(df) == 0) return(NA_real_)
  df %>%
    group_by(run) %>%
    slice_tail(n = STEADY_LAST) %>%
    ungroup() %>%
    summarise(v = mean(.data[[METRIC]] / view, na.rm = TRUE)) %>%
    pull(v)
}

# Prepare time-series data: propByz, average across runs, thin to every 50 rounds
prepare_ts <- function(df) {
  df$propByz <- df[[METRIC]] / view
  df %>%
    group_by(strategy, time) %>%
    summarise(propByz = mean(propByz, na.rm = TRUE), .groups = "drop") %>%
    filter(time %% 50 == 0)
}

# ─────────────────────────────────────────────────────────────
#  Courbe 1 — Time series (fixed f=C1_F, t=C1_T)
# ─────────────────────────────────────────────────────────────
plot_courbe1 <- function() {
  f_count <- as.integer(nodes * C1_F / 100)
  t_count <- as.integer(nodes * C1_T / 100)

  rows <- list(
    read_runs("bm",    f_count, 0,       0.0, "BM"),
    read_runs("decay", f_count, t_count, 0.0, "BMDecay")
  )
  for (i in seq_along(ER_VALS)) {
    rows <- c(rows, list(
      read_runs("evict", f_count, t_count, ER_VALS[i], er_labels[i])
    ))
  }

  df <- do.call(rbind, Filter(function(x) nrow(x) > 0, rows))
  if (nrow(df) == 0) { cat("Courbe 1: no data found\n"); return() }

  level_order <- c("BM", "BMDecay", er_labels)
  present <- intersect(level_order, unique(df$strategy))
  avg <- prepare_ts(df)
  avg$strategy <- factor(avg$strategy, levels = present)

  p <- ggplot(avg, aes(x = time, y = propByz, color = strategy,
                       linetype = strategy, group = strategy)) +
    geom_vline(xintercept = ATTACK_START, color = "gray50",
               linetype = "dotted", linewidth = 0.8) +
    geom_hline(yintercept = C1_F / 100, color = "tomato",
               linetype = "dotted", linewidth = 0.8) +
    geom_line(linewidth = line_size) +
    scale_color_manual(values = custom_colors[present], drop = FALSE) +
    scale_linetype_manual(values = custom_lty[present], drop = FALSE) +
    labs(
      title = sprintf("Courbe 1 — Time series  (f=%d%%, t=%d%%)", C1_F, C1_T),
      x = expression(bold("Rounds")),
      y = expression(bold("Prop. byzantins in view (honest nodes)"))
    ) +
    coord_cartesian(ylim = c(0, 1)) +
    scale_x_continuous(
      breaks = c(0, 5000, 10000, 15000, 20000),
      labels = c("0", "5K", "10K", "15K", "20K"),
      sec.axis = dup_axis(labels = NULL, name = NULL)
    ) +
    scale_y_continuous(
      breaks       = seq(0, 1, by = 0.1),
      minor_breaks = seq(0, 1, by = 0.05),
      sec.axis = dup_axis(labels = NULL, name = NULL)
    ) +
    mytheme +
    theme(legend.position = c(0.5, 0.75)) +
    guides(color    = guide_legend(ncol = 1),
           linetype = guide_legend(ncol = 1))

  dir.create("results", showWarnings = FALSE)
  outfile <- sprintf("results/courbe1_timeseries_%gKB.pdf", budget)
  pdf(outfile, width = width, height = height)
  print(p)
  dev.off()
  cat("Saved to:", outfile, "\n")
}

# ─────────────────────────────────────────────────────────────
#  Courbe 2 — Gain ER+Merge vs BMDecay (bar chart, 1 panel / t%)
# ─────────────────────────────────────────────────────────────
plot_courbe2 <- function() {
  rows <- list()
  for (t in T_FRACS) {
    t_count <- as.integer(nodes * t / 100)
    for (f in F_FRACS) {
      f_count <- as.integer(nodes * f / 100)
      d_val   <- steady("decay", f_count, t_count, 0.0)
      for (i in seq_along(ER_VALS)) {
        e_val <- steady("evict", f_count, t_count, ER_VALS[i])
        gain  <- if (!is.na(d_val) && d_val > 1e-9) (d_val - e_val) / d_val * 100 else NA_real_
        rows <- c(rows, list(data.frame(
          t_pct  = t,
          f_pct  = f,
          er_lbl = sprintf("ER=%.0f%%", ER_VALS[i] * 100),
          gain   = gain
        )))
      }
    }
  }
  df <- do.call(rbind, rows)
  df$f_label <- factor(sprintf("f=%d%%", df$f_pct), levels = sprintf("f=%d%%", F_FRACS))
  df$er_lbl  <- factor(df$er_lbl, levels = sprintf("ER=%.0f%%", ER_VALS * 100))

  plots <- list()
  for (i in seq_along(T_FRACS)) {
    t   <- T_FRACS[i]
    sub <- df %>% filter(t_pct == t)

    p <- ggplot(sub, aes(x = f_label, y = gain, fill = er_lbl)) +
      geom_col(position = position_dodge(width = 0.75), width = 0.7,
               color = "white", linewidth = 0.3) +
      geom_text(aes(label = sprintf("%.1f%%", gain),
                    vjust = ifelse(!is.na(gain) & gain >= 0, -0.4, 1.2)),
                position = position_dodge(width = 0.75),
                size = 3, fontface = "bold") +
      geom_hline(yintercept = 0, color = "black", linewidth = 0.8) +
      scale_fill_manual(values = er_bar_colors) +
      labs(
        title = sprintf("t=%d%% trusted nodes", t),
        x = expression(bold("Byzantine fraction")),
        y = if (i == 1) expression(bold("Gain (%)  =  (BMDecay − ER+Merge) / BMDecay")) else NULL
      ) +
      mytheme +
      theme(
        legend.position = if (i == 1) c(0.25, 0.85) else "none",
        axis.text.x = element_text(size = 12, face = "bold")
      ) +
      guides(fill = guide_legend(ncol = 1))

    plots[[i]] <- p
  }

  dir.create("results", showWarnings = FALSE)
  outfile <- sprintf("results/courbe2_gain_%gKB.pdf", budget)
  pdf(outfile, width = width, height = height)
  grid.arrange(grobs = plots, nrow = 1, ncol = length(T_FRACS))
  dev.off()
  cat("Saved to:", outfile, "\n")
}

# ─────────────────────────────────────────────────────────────
#  Courbe 3 — Recap: propByz in view vs Byzantine fraction in system
# ─────────────────────────────────────────────────────────────
plot_courbe3 <- function() {
  plots <- list()

  for (i in seq_along(T_FRACS)) {
    t       <- T_FRACS[i]
    t_count <- as.integer(nodes * t / 100)

    bm_ss <- sapply(F_FRACS, function(f)
      steady("bm", as.integer(nodes * f / 100), 0L, 0.0))
    dc_ss <- sapply(F_FRACS, function(f)
      steady("decay", as.integer(nodes * f / 100), t_count, 0.0))

    df <- rbind(
      data.frame(f_pct = F_FRACS, propByz = bm_ss * 100, strategy = "BM"),
      data.frame(f_pct = F_FRACS, propByz = dc_ss * 100, strategy = "BMDecay")
    )
    for (j in seq_along(ER_VALS)) {
      er_ss <- sapply(F_FRACS, function(f)
        steady("evict", as.integer(nodes * f / 100), t_count, ER_VALS[j]))
      df <- rbind(df, data.frame(
        f_pct    = F_FRACS,
        propByz  = er_ss * 100,
        strategy = er_labels[j]
      ))
    }

    ref_df <- data.frame(f_pct = F_FRACS, propByz = F_FRACS)

    level_order <- c("BM", "BMDecay", er_labels)
    present     <- intersect(level_order, unique(df$strategy))
    df$strategy <- factor(df$strategy, levels = present)

    p <- ggplot(df, aes(x = f_pct, y = propByz, color = strategy,
                        linetype = strategy, shape = strategy, group = strategy)) +
      geom_line(data = ref_df, aes(x = f_pct, y = propByz),
                color = "gray40", linetype = "dotted", linewidth = 0.8,
                inherit.aes = FALSE) +
      geom_line(linewidth = line_size) +
      geom_point(size = point_size) +
      scale_color_manual(values = custom_colors[present], drop = FALSE) +
      scale_linetype_manual(values = custom_lty[present], drop = FALSE) +
      scale_shape_manual(values = custom_shape[present], drop = FALSE) +
      labs(
        title = sprintf("t=%d%% trusted nodes", t),
        x = expression(bold("Byzantins in system (%)")),
        y = if (i == 1) expression(bold("Byzantins in view — honest (%)")) else NULL
      ) +
      scale_x_continuous(breaks = F_FRACS,
                         sec.axis = dup_axis(labels = NULL, name = NULL)) +
      scale_y_continuous(breaks = seq(0, 50, by = 10),
                         minor_breaks = seq(0, 50, by = 5),
                         sec.axis = dup_axis(labels = NULL, name = NULL)) +
      coord_cartesian(xlim = c(7, 43), ylim = c(0, NA)) +
      mytheme +
      theme(legend.position = if (i == 1) c(0.35, 0.75) else "none") +
      guides(color    = guide_legend(ncol = 1),
             linetype = guide_legend(ncol = 1),
             shape    = guide_legend(ncol = 1))

    plots[[i]] <- p
  }

  dir.create("results", showWarnings = FALSE)
  outfile <- sprintf("results/courbe3_recap_%gKB.pdf", budget)
  pdf(outfile, width = width, height = height)
  grid.arrange(grobs = plots, nrow = 1, ncol = length(T_FRACS))
  dev.off()
  cat("Saved to:", outfile, "\n")
}

# ─────────────────────────────────────────────────────────────
#  Main
# ─────────────────────────────────────────────────────────────
if (is.na(budget)) stop("Usage: Rscript plot_curves.r <budget_KB> [<nruns>]")

cat(sprintf("Budget: %g KB  |  runs: %d  |  data dir: %s\n", budget, nruns, OUTDIR))
plot_courbe1()
plot_courbe2()
plot_courbe3()
cat("Done.\n")
