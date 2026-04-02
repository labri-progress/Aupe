#!/usr/bin/env Rscript
# Simulation plotter — Aupe Byzantine-resilient peer sampling
#
# Courbe 1 : Time series — BM, BMDecay, ER+Merge (fixed f=30%, t=10%)
# Courbe 2 : Relative gain ER+Merge vs BMDecay (steady state, bar chart)
# Courbe 3 : Recap — propByz in view vs propByz in system

library(ggplot2)
library(dplyr)
library(gridExtra)

# ─────────────────────────────────────────────────────────────
#  Parameters
# ─────────────────────────────────────────────────────────────
CACHE_DIR    <- "sim_cache"
VIEW_SIZE    <- 20
T_ROUNDS     <- 3000
STEADY_LAST  <- 500
ATTACK_START <- 500

F_FRACS  <- c(10, 20, 30, 40)
T_FRACS  <- c(5, 10, 20)
ER_VALS  <- c(20, 50, 80)
C1_F     <- 30
C1_T     <- 10

METRIC <- "h_avgByzN"   # honest-node average byzantine count

# ─────────────────────────────────────────────────────────────
#  Theme (same as plot_three_figures.r)
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

mytheme <- mytheme +
  guides() +
  theme(
    axis.ticks.x.top       = element_line(color = "black", linewidth = 1),
    axis.ticks.y.right     = element_line(color = "black", linewidth = 1),
    axis.minor.ticks.x.top  = element_line(color = "black", linewidth = 0.5),
    axis.minor.ticks.y.right = element_line(color = "black", linewidth = 0.5),
    axis.text.x.top        = element_blank(),
    axis.text.y.right      = element_blank()
  )

# ─────────────────────────────────────────────────────────────
#  Colors & linetypes
# ─────────────────────────────────────────────────────────────
custom_colors <- c(
  "BM"           = "#882EE6",
  "BMDecay"      = "#000000",
  "ER=20%+Merge" = "#f4d03f",
  "ER=50%+Merge" = "#e67e22",
  "ER=80%+Merge" = "#c0392b"
)

custom_lty <- c(
  "BM"           = "solid",
  "BMDecay"      = "dashed",
  "ER=20%+Merge" = "solid",
  "ER=50%+Merge" = "solid",
  "ER=80%+Merge" = "solid"
)

er_bar_colors <- c(
  "ER=20%" = "#f4d03f",
  "ER=50%" = "#e67e22",
  "ER=80%" = "#c0392b"
)

# ─────────────────────────────────────────────────────────────
#  Cache reader
# ─────────────────────────────────────────────────────────────
read_cache <- function(tag) {
  fname <- file.path(CACHE_DIR, paste0(tag, ".txt"))
  if (!file.exists(fname)) {
    cat("Warning: file not found:", fname, "\n")
    return(NULL)
  }
  d <- tryCatch(
    read.table(fname, header = TRUE, fill = TRUE,
               na.strings = c("NaN", "Inf", "-Inf", "nan", "inf")),
    error = function(e) { cat("Error reading", fname, ":", conditionMessage(e), "\n"); NULL }
  )
  d
}

# Steady-state mean of METRIC over last STEADY_LAST rows
steady <- function(tag) {
  d <- read_cache(tag)
  if (is.null(d) || !(METRIC %in% names(d))) return(NA_real_)
  tail_d <- tail(d, STEADY_LAST)
  mean(tail_d[[METRIC]] / VIEW_SIZE, na.rm = TRUE)
}

# ─────────────────────────────────────────────────────────────
#  Courbe 1 — Time series (fixed f=C1_F, t=C1_T)
# ─────────────────────────────────────────────────────────────
plot_courbe1 <- function() {
  collect <- function(tag, label) {
    d <- read_cache(tag)
    if (is.null(d) || !(METRIC %in% names(d))) return(NULL)
    data.frame(
      time     = d$time,
      propByz  = d[[METRIC]] / VIEW_SIZE,
      strategy = label
    )
  }

  rows <- list(
    collect(sprintf("bm_f%d",              C1_F),        "BM"),
    collect(sprintf("decay_f%d_t%d",       C1_F, C1_T),  "BMDecay")
  )
  for (er in ER_VALS) {
    lbl <- sprintf("ER=%d%%+Merge", er)
    rows <- c(rows, list(collect(sprintf("evict_f%d_t%d_er%d", C1_F, C1_T, er), lbl)))
  }

  df <- do.call(rbind, Filter(Negate(is.null), rows))
  if (is.null(df) || nrow(df) == 0) { cat("Courbe 1: no data\n"); return() }

  level_order  <- c("BM", "BMDecay", sprintf("ER=%d%%+Merge", ER_VALS))
  present      <- intersect(level_order, unique(df$strategy))
  df$strategy  <- factor(df$strategy, levels = present)

  # downsample: keep every 10th round to reduce plot weight
  df <- df %>% filter(time %% 10 == 0)

  ref_line  <- C1_F / 100
  attack_df <- data.frame(x = ATTACK_START)

  p <- ggplot(df, aes(x = time, y = propByz, color = strategy,
                      linetype = strategy, group = strategy)) +
    geom_vline(xintercept = ATTACK_START, color = "gray50", linetype = "dotted",
               linewidth = 0.8) +
    geom_hline(yintercept = ref_line, color = "tomato", linetype = "dotted",
               linewidth = 0.8) +
    geom_line(linewidth = line_size) +
    scale_color_manual(values = custom_colors[present], drop = FALSE) +
    scale_linetype_manual(values = custom_lty[present], drop = FALSE) +
    labs(
      title = sprintf("Courbe 1 — Time series  (f=%d%%, t=%d%%, flood fixed)", C1_F, C1_T),
      x = expression(bold("Rounds")),
      y = expression(bold("Prop. byzantins in view (honest nodes)"))
    ) +
    coord_cartesian(ylim = c(0, C1_F / 100 * 1.4)) +
    scale_x_continuous(
      breaks   = pretty(range(df$time), n = 6),
      sec.axis = dup_axis(labels = NULL, name = NULL)
    ) +
    scale_y_continuous(
      breaks        = seq(0, 1, by = 0.1),
      minor_breaks  = seq(0, 1, by = 0.05),
      sec.axis = dup_axis(labels = NULL, name = NULL)
    ) +
    mytheme +
    theme(legend.position = c(0.5, 0.75)) +
    guides(color    = guide_legend(ncol = 1),
           linetype = guide_legend(ncol = 1))

  dir.create("results", showWarnings = FALSE)
  outfile <- "results/courbe1_timeseries.pdf"
  pdf(outfile, width = width, height = height)
  print(p)
  dev.off()
  cat("Saved to:", outfile, "\n")
}

# ─────────────────────────────────────────────────────────────
#  Courbe 2 — Relative gain ER+Merge vs BMDecay (bar chart)
# ─────────────────────────────────────────────────────────────
plot_courbe2 <- function() {
  gain_rows <- list()
  for (t in T_FRACS) {
    for (f in F_FRACS) {
      d_val <- steady(sprintf("decay_f%d_t%d", f, t))
      for (er in ER_VALS) {
        e_val <- steady(sprintf("evict_f%d_t%d_er%d", f, t, er))
        gain  <- if (!is.na(d_val) && d_val > 1e-9) (d_val - e_val) / d_val * 100 else NA_real_
        gain_rows <- c(gain_rows, list(data.frame(
          t_pct   = t,
          f_pct   = f,
          er_lbl  = sprintf("ER=%d%%", er),
          gain    = gain
        )))
      }
    }
  }
  df <- do.call(rbind, gain_rows)
  df$f_label <- factor(sprintf("f=%d%%", df$f_pct), levels = sprintf("f=%d%%", F_FRACS))
  df$er_lbl  <- factor(df$er_lbl, levels = sprintf("ER=%d%%", ER_VALS))

  plots <- list()
  for (i in seq_along(T_FRACS)) {
    t   <- T_FRACS[i]
    sub <- df %>% filter(t_pct == t)

    p <- ggplot(sub, aes(x = f_label, y = gain, fill = er_lbl)) +
      geom_col(position = position_dodge(width = 0.75), width = 0.7,
               color = "white", linewidth = 0.3) +
      geom_text(aes(label = sprintf("%.1f%%", gain),
                    vjust = ifelse(gain >= 0, -0.4, 1.2)),
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
        legend.position = if (i == 1) c(0.5, 0.85) else "none",
        axis.text.x = element_text(size = 12, face = "bold")
      ) +
      guides(fill = guide_legend(ncol = 1))

    plots[[i]] <- p
  }

  dir.create("results", showWarnings = FALSE)
  outfile <- "results/courbe2_gain.pdf"
  pdf(outfile, width = width, height = height)
  grid.arrange(grobs = plots, nrow = 1, ncol = length(T_FRACS))
  dev.off()
  cat("Saved to:", outfile, "\n")
}

# ─────────────────────────────────────────────────────────────
#  Courbe 3 — Recap: propByz in view vs propByz in system
# ─────────────────────────────────────────────────────────────
plot_courbe3 <- function() {
  plots <- list()

  for (i in seq_along(T_FRACS)) {
    t <- T_FRACS[i]

    # Build steady-state data frame
    rows <- list()

    # Sans défense reference (y = x)
    ref_df <- data.frame(f_pct = F_FRACS, propByz = F_FRACS / 100,
                         strategy = "Sans défense")

    # BM
    bm_df <- data.frame(
      f_pct    = F_FRACS,
      propByz  = sapply(F_FRACS, function(f) steady(sprintf("bm_f%d", f))),
      strategy = "BM"
    )

    # BMDecay
    dc_df <- data.frame(
      f_pct    = F_FRACS,
      propByz  = sapply(F_FRACS, function(f) steady(sprintf("decay_f%d_t%d", f, t))),
      strategy = "BMDecay"
    )

    df <- rbind(bm_df, dc_df)

    # ER+Merge
    for (er in ER_VALS) {
      lbl <- sprintf("ER=%d%%+Merge", er)
      er_df <- data.frame(
        f_pct    = F_FRACS,
        propByz  = sapply(F_FRACS, function(f) steady(sprintf("evict_f%d_t%d_er%d", f, t, er))),
        strategy = lbl
      )
      df <- rbind(df, er_df)
    }

    level_order <- c("BM", "BMDecay", sprintf("ER=%d%%+Merge", ER_VALS))
    present     <- intersect(level_order, unique(df$strategy))
    df$strategy <- factor(df$strategy, levels = present)

    p <- ggplot(df, aes(x = f_pct, y = propByz * 100, color = strategy,
                        linetype = strategy, shape = strategy, group = strategy)) +
      geom_line(data = ref_df, aes(x = f_pct, y = propByz * 100),
                color = "gray40", linetype = "dotted", linewidth = 0.8,
                inherit.aes = FALSE) +
      geom_line(linewidth = line_size) +
      geom_point(size = point_size) +
      scale_color_manual(values = custom_colors[present], drop = FALSE) +
      scale_linetype_manual(values = custom_lty[present], drop = FALSE) +
      scale_shape_manual(values = c("BM" = 15, "BMDecay" = 17,
                                    "ER=20%+Merge" = 16, "ER=50%+Merge" = 18, "ER=80%+Merge" = 25),
                         drop = FALSE) +
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
  outfile <- "results/courbe3_recap.pdf"
  pdf(outfile, width = width, height = height)
  grid.arrange(grobs = plots, nrow = 1, ncol = length(T_FRACS))
  dev.off()
  cat("Saved to:", outfile, "\n")
}

# ─────────────────────────────────────────────────────────────
#  Main
# ─────────────────────────────────────────────────────────────
cat("Generating curves...\n")
plot_courbe1()
plot_courbe2()
plot_courbe3()
cat("Done.\n")
