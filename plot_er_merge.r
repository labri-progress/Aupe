#!/usr/bin/env Rscript
# Usage: Rscript plot_er_merge.r <budget> [<nruns>]
#
# Courbe 1 : Time series (valeurs absolues)
#            BM (sans merge), BMDecay (sans merge), ER%+Merge t%
#            Grid: 1 panel par f (f=10,20,30,40%)
#
# Courbe 2 : Gain ER%+Merge t% vs BMDecay (sans merge), par valeur de ER
#            Grid: 1 panel par ER (ER=50%, ER=80%)
#            x = f%,  barres groupées par t%
#
# Courbe 3 : Récap — prop. byz. dans la vue vs prop. byz. dans le système
#            BM (sans merge), BMDecay (sans merge), ER%+Merge t%
#            Grid: 1 panel par t% (t=5%, 10%, 20%)
#
# ER : 50, 80 %   |   t : 5, 10, 20 %   |   f : 10, 20, 30, 40 %

args <- commandArgs(trailingOnly = TRUE)

library(ggplot2)
library(dplyr)
library(gridExtra)

# ─────────────────────────────────────────────────────────────
#  Parameters
# ─────────────────────────────────────────────────────────────
budget <- as.numeric(args[1])
nruns  <- if (length(args) >= 2) as.integer(args[2]) else 1L

if (is.na(budget)) stop("Usage: Rscript plot_er_merge.r <budget_KB> [<nruns>]")

OUTDIR       <- "output_byz"
nodes        <- 1000
view         <- 20
ATTACK_START <- 10000
STEADY_LAST  <- 500

F_FRACS  <- c(10, 20, 30, 40)   # Byzantine fraction in system (%)
T_FRACS  <- c(5, 10, 20)        # Trusted node fraction (%)
ER_VALS  <- c(0.5, 0.8)         # Eviction rates

METRIC <- "avgByzN"

# ─────────────────────────────────────────────────────────────
#  Theme
# ─────────────────────────────────────────────────────────────
line_size  <- 0.6
point_size <- 2.5

mytheme <- theme(
  panel.grid.major       = element_line(color = "gray90", linewidth = 0.5),
  panel.grid.minor       = element_line(color = "gray95", linewidth = 0.25),
  panel.background       = element_rect(fill = "white"),
  plot.background        = element_rect(fill = "white"),
  panel.border           = element_rect(colour = "black", linewidth = 1, fill = NA),
  legend.spacing.y       = unit(0.005, "cm"),
  text                   = element_text(size = 12, color = "black"),
  axis.title.x           = element_text(size = 14, face = "bold"),
  axis.title.y           = element_text(size = 12, face = "bold"),
  axis.text.x            = element_text(size = 14, face = "bold"),
  axis.text.y            = element_text(size = 14, face = "bold"),
  plot.title             = element_text(size = 14, face = "bold"),
  legend.text            = element_text(size = 10, face = "bold"),
  legend.title           = element_blank(),
  legend.background      = element_rect(fill = "transparent", colour = NA),
  legend.box.background  = element_rect(fill = "transparent", colour = NA),
  axis.ticks             = element_line(color = "black", linewidth = 1),
  axis.ticks.length      = unit(4, "pt"),
  axis.minor.ticks.length = unit(2, "pt")
)
mytheme <- mytheme + guides() + theme(
  axis.ticks.x.top         = element_line(color = "black", linewidth = 1),
  axis.ticks.y.right       = element_line(color = "black", linewidth = 1),
  axis.minor.ticks.x.top   = element_line(color = "black", linewidth = 0.5),
  axis.minor.ticks.y.right = element_line(color = "black", linewidth = 0.5),
  axis.text.x.top          = element_blank(),
  axis.text.y.right        = element_blank()
)

# ─────────────────────────────────────────────────────────────
#  Labels for all (ER, t) combinations
#  Order: ER=50%+t=5%, ER=50%+t=10%, ER=50%+t=20%,
#         ER=80%+t=5%, ER=80%+t=10%, ER=80%+t=20%
# ─────────────────────────────────────────────────────────────
er_t_labels <- c()
for (er in ER_VALS) {
  for (t in T_FRACS) {
    er_t_labels <- c(er_t_labels, sprintf("ER=%.0f%%+t=%d%%", er * 100, t))
  }
}

# Colors: warm (yellow→red) for ER=50%, cool (light→dark blue) for ER=80%
er50_colors <- c("#f1c40f", "#e67e22", "#c0392b")   # t=5%, 10%, 20%
er80_colors <- c("#85c1e9", "#2980b9", "#1a5276")   # t=5%, 10%, 20%
er_t_colors <- setNames(c(er50_colors, er80_colors), er_t_labels)

# Linetypes: ER=50% → solid, ER=80% → dashed
er_t_ltys <- setNames(
  c(rep("solid",  length(T_FRACS)),
    rep("dashed", length(T_FRACS))),
  er_t_labels
)

# Shapes: cycle through 16/17/15 for t=5/10/20%, same for both ERs
er_t_shapes <- setNames(c(16L, 17L, 15L, 16L, 17L, 15L), er_t_labels)

custom_colors <- c("BM" = "#882EE6", "BMDecay" = "#000000", er_t_colors)
custom_lty    <- c("BM" = "solid",   "BMDecay" = "dotdash",  er_t_ltys)
custom_shape  <- c("BM" = 8L,        "BMDecay" = 4L,         er_t_shapes)

# ─────────────────────────────────────────────────────────────
#  File-name builder  (matches run_experimentsK convention)
# ─────────────────────────────────────────────────────────────
fname <- function(strat, f_count, t_count = 0, eviction_rate = 0.0, run = 1) {
  trusted_tag  <- if (t_count > 0)          sprintf("-x%d",  t_count)        else ""
  eviction_tag <- if (eviction_rate != 0.0)  sprintf("-e%g", eviction_rate)  else ""
  file.path(OUTDIR,
            sprintf("%s-N%d-v%d-f%d-y%g%s%s-run%d",
                    strat, nodes, view, f_count, budget,
                    trusted_tag, eviction_tag, run))
}

# ─────────────────────────────────────────────────────────────
#  Reader — averages over runs
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

# Steady-state proportion (mean of last STEADY_LAST rows across runs)
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

# Time-series average (thin to every 50 rounds)
prepare_ts <- function(df) {
  df$propByz <- df[[METRIC]] / view
  df %>%
    group_by(strategy, time) %>%
    summarise(propByz = mean(propByz, na.rm = TRUE), .groups = "drop") %>%
    filter(time %% 50 == 0)
}

# ─────────────────────────────────────────────────────────────
#  Courbe 1 — Time series, 1 panel per f%
# ─────────────────────────────────────────────────────────────
plot_courbe1 <- function() {
  cat("Building Courbe 1 ...\n")
  plots <- list()

  for (i in seq_along(F_FRACS)) {
    f       <- F_FRACS[i]
    f_count <- as.integer(nodes * f / 100)

    # Baselines (no merge, t_count = 0)
    rows <- list(
      read_runs("bm",    f_count, 0L, 0.0, "BM"),
      read_runs("decay", f_count, 0L, 0.0, "BMDecay")
    )
    # ER + Merge variants
    for (er in ER_VALS) {
      for (t in T_FRACS) {
        t_count <- as.integer(nodes * t / 100)
        lbl     <- sprintf("ER=%.0f%%+t=%d%%", er * 100, t)
        rows    <- c(rows, list(read_runs("evict", f_count, t_count, er, lbl)))
      }
    }

    df <- do.call(rbind, Filter(function(x) nrow(x) > 0, rows))
    if (nrow(df) == 0) {
      plots[[i]] <- ggplot() + labs(title = sprintf("f=%d%% — no data", f)) + mytheme
      next
    }

    level_order  <- c("BM", "BMDecay", er_t_labels)
    present      <- intersect(level_order, unique(df$strategy))
    avg          <- prepare_ts(df)
    avg$strategy <- factor(avg$strategy, levels = present)

    p <- ggplot(avg, aes(x = time, y = propByz, color = strategy,
                         linetype = strategy, group = strategy)) +
      geom_vline(xintercept = ATTACK_START, color = "gray60",
                 linetype = "dotted", linewidth = 0.8) +
      geom_hline(yintercept = f / 100, color = "tomato",
                 linetype = "dotted", linewidth = 0.8) +
      geom_line(linewidth = line_size) +
      scale_color_manual(values = custom_colors[present], drop = FALSE) +
      scale_linetype_manual(values = custom_lty[present], drop = FALSE) +
      labs(
        title = sprintf("f = %d%%", f),
        x     = expression(bold("Rounds")),
        y     = if (i == 1) expression(bold("Prop. byz. in view")) else NULL
      ) +
      coord_cartesian(ylim = c(0, 1)) +
      scale_x_continuous(
        breaks    = c(0, 5000, 10000, 15000, 20000),
        labels    = c("0", "5K", "10K", "15K", "20K"),
        sec.axis  = dup_axis(labels = NULL, name = NULL)
      ) +
      scale_y_continuous(
        breaks        = seq(0, 1, by = 0.2),
        minor_breaks  = seq(0, 1, by = 0.1),
        sec.axis      = dup_axis(labels = NULL, name = NULL)
      ) +
      mytheme +
      theme(legend.position = if (i == 1) c(0.45, 0.68) else "none") +
      guides(color    = guide_legend(ncol = 1),
             linetype = guide_legend(ncol = 1))

    plots[[i]] <- p
  }

  dir.create("results", showWarnings = FALSE)
  outfile <- sprintf("results/courbe1_timeseries_%gKB.pdf", budget)
  pdf(outfile, width = 16, height = 16 / 3.5)
  grid.arrange(grobs = plots, nrow = 1, ncol = length(F_FRACS))
  dev.off()
  cat("Saved:", outfile, "\n")
}

# ─────────────────────────────────────────────────────────────
#  Courbe 2 — Gain ER%+Merge vs BMDecay (sans merge), par ER
# ─────────────────────────────────────────────────────────────
plot_courbe2 <- function() {
  cat("Building Courbe 2 ...\n")

  rows <- list()
  for (er in ER_VALS) {
    for (t in T_FRACS) {
      t_count <- as.integer(nodes * t / 100)
      for (f in F_FRACS) {
        f_count <- as.integer(nodes * f / 100)
        d_val   <- steady("decay", f_count, 0L, 0.0)
        e_val   <- steady("evict", f_count, t_count, er)
        gain    <- if (!is.na(d_val) && d_val > 1e-9) {
          (d_val - e_val) / d_val * 100
        } else NA_real_
        rows <- c(rows, list(data.frame(
          er_lbl = sprintf("ER=%.0f%%", er * 100),
          t_lbl  = sprintf("t=%d%%",   t),
          f_pct  = f,
          gain   = gain
        )))
      }
    }
  }

  df        <- do.call(rbind, rows)
  df$f_label <- factor(sprintf("f=%d%%", df$f_pct),
                        levels = sprintf("f=%d%%", F_FRACS))
  df$t_lbl   <- factor(df$t_lbl,
                        levels = sprintf("t=%d%%", T_FRACS))
  df$er_lbl  <- factor(df$er_lbl,
                        levels = sprintf("ER=%.0f%%", ER_VALS * 100))

  t_fill_colors <- setNames(c("#27ae60", "#e67e22", "#c0392b"),
                            sprintf("t=%d%%", T_FRACS))

  plots <- list()
  for (i in seq_along(ER_VALS)) {
    er_lbl <- sprintf("ER=%.0f%%", ER_VALS[i] * 100)
    sub    <- df %>% filter(er_lbl == !!er_lbl)

    p <- ggplot(sub, aes(x = f_label, y = gain, fill = t_lbl)) +
      geom_col(position = position_dodge(width = 0.75), width = 0.65,
               color = "white", linewidth = 0.3) +
      geom_text(aes(label = ifelse(is.na(gain), "N/A",
                                   sprintf("%.1f%%", gain)),
                    vjust = ifelse(!is.na(gain) & gain >= 0, -0.4, 1.2)),
                position = position_dodge(width = 0.75),
                size = 3, fontface = "bold") +
      geom_hline(yintercept = 0, color = "black", linewidth = 0.8) +
      scale_fill_manual(values = t_fill_colors) +
      labs(
        title = er_lbl,
        x     = expression(bold("Byzantine fraction")),
        y     = if (i == 1)
          expression(bold("Gain (%)  =  (BMDecay \u2212 ER+Merge) / BMDecay"))
          else NULL
      ) +
      mytheme +
      theme(
        legend.position = if (i == 1) c(0.25, 0.85) else "none",
        axis.text.x     = element_text(size = 12, face = "bold")
      ) +
      guides(fill = guide_legend(ncol = 1))

    plots[[i]] <- p
  }

  dir.create("results", showWarnings = FALSE)
  outfile <- sprintf("results/courbe2_gain_%gKB.pdf", budget)
  pdf(outfile, width = 10, height = 10 / 3.0)
  grid.arrange(grobs = plots, nrow = 1, ncol = length(ER_VALS))
  dev.off()
  cat("Saved:", outfile, "\n")
}

# ─────────────────────────────────────────────────────────────
#  Courbe 3 — Récap, 1 panel par t%
# ─────────────────────────────────────────────────────────────
plot_courbe3 <- function() {
  cat("Building Courbe 3 ...\n")
  plots <- list()

  # Baselines are constant across panels (no merge)
  bm_ss <- sapply(F_FRACS, function(f)
    steady("bm",    as.integer(nodes * f / 100), 0L, 0.0))
  dc_ss <- sapply(F_FRACS, function(f)
    steady("decay", as.integer(nodes * f / 100), 0L, 0.0))

  for (i in seq_along(T_FRACS)) {
    t       <- T_FRACS[i]
    t_count <- as.integer(nodes * t / 100)

    df <- rbind(
      data.frame(f_pct = F_FRACS, propByz = bm_ss * 100, strategy = "BM"),
      data.frame(f_pct = F_FRACS, propByz = dc_ss * 100, strategy = "BMDecay")
    )
    for (er in ER_VALS) {
      lbl   <- sprintf("ER=%.0f%%+t=%d%%", er * 100, t)
      er_ss <- sapply(F_FRACS, function(f)
        steady("evict", as.integer(nodes * f / 100), t_count, er))
      df <- rbind(df, data.frame(
        f_pct    = F_FRACS,
        propByz  = er_ss * 100,
        strategy = lbl
      ))
    }

    ref_df      <- data.frame(f_pct = F_FRACS, propByz = F_FRACS)
    level_order <- c("BM", "BMDecay",
                     sprintf("ER=%.0f%%+t=%d%%", ER_VALS * 100, t))
    present     <- intersect(level_order, unique(df$strategy))
    df$strategy <- factor(df$strategy, levels = present)

    p <- ggplot(df, aes(x = f_pct, y = propByz, color = strategy,
                        linetype = strategy, shape = strategy,
                        group = strategy)) +
      geom_line(data = ref_df, aes(x = f_pct, y = propByz),
                color = "gray40", linetype = "dotted", linewidth = 0.8,
                inherit.aes = FALSE) +
      geom_line(linewidth = line_size) +
      geom_point(size = point_size) +
      scale_color_manual(values = custom_colors[present], drop = FALSE) +
      scale_linetype_manual(values = custom_lty[present], drop = FALSE) +
      scale_shape_manual(values = custom_shape[present], drop = FALSE) +
      labs(
        title = sprintf("t = %d%% trusted", t),
        x     = expression(bold("Byzantins in system (%)")),
        y     = if (i == 1) expression(bold("Byzantins in view — honest (%)")) else NULL
      ) +
      scale_x_continuous(
        breaks   = F_FRACS,
        sec.axis = dup_axis(labels = NULL, name = NULL)
      ) +
      scale_y_continuous(
        breaks        = seq(0, 50, by = 10),
        minor_breaks  = seq(0, 50, by = 5),
        sec.axis      = dup_axis(labels = NULL, name = NULL)
      ) +
      coord_cartesian(xlim = c(7, 43), ylim = c(0, NA)) +
      mytheme +
      theme(legend.position = if (i == 1) c(0.30, 0.75) else "none") +
      guides(color    = guide_legend(ncol = 1),
             linetype = guide_legend(ncol = 1),
             shape    = guide_legend(ncol = 1))

    plots[[i]] <- p
  }

  dir.create("results", showWarnings = FALSE)
  outfile <- sprintf("results/courbe3_recap_%gKB.pdf", budget)
  pdf(outfile, width = 12, height = 12 / 3.0)
  grid.arrange(grobs = plots, nrow = 1, ncol = length(T_FRACS))
  dev.off()
  cat("Saved:", outfile, "\n")
}

# ─────────────────────────────────────────────────────────────
#  Main
# ─────────────────────────────────────────────────────────────
cat(sprintf("Budget: %g KB  |  runs: %d  |  data dir: %s\n", budget, nruns, OUTDIR))
plot_courbe1()
plot_courbe2()
plot_courbe3()
cat("Done.\n")
