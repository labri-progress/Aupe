#!/usr/bin/env Rscript
# Usage: Rscript plot_three_figures.r <budget> [<merge_subdir>]
# Produces PDFs:
#   fig1: BM, BMDecay (t=0%), Evict
#   fig2: BM, BMDecay (t=0%), BMDecay t=5%/10%/20%
#   fig3: BMDecay + BMDecay t=% vs Evict + Evict t=%
#   fig4: BM, BMDecay, Evict t=5%/20%

args <- commandArgs(trailingOnly = TRUE)

library(ggplot2)
library(dplyr)
library(gridExtra)

# --- Parameters ---
budget         <- as.numeric(args[1])
merge_subdir   <- "attack"
eviction_rate  <- if (length(args) >= 2) as.numeric(args[2]) else 0.0

nodes        <- 1000
view         <- 20
nruns        <- 1
faulty_pcts  <- c(10, 20, 30, 40)
trusted_pcts <- c(5, 10, 20)

results_dir  <- "output_byz"
merge_dir    <- "output_byz"

# --- Theme ---
line_size  <- 0.5
point_size <- 1
ratio      <- 3.5
width      <- 12
height     <- width / ratio

mytheme <- theme(
  panel.grid.major = element_line(color = "gray90", linewidth=0.5),
  panel.grid.minor = element_line(color = "gray95", linewidth=0.25),
  panel.background = element_rect(fill = "white"),
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
    axis.ticks.x.top  = element_line(color = "black", linewidth = 1),
    axis.ticks.y.right = element_line(color = "black", linewidth = 1),
    axis.minor.ticks.x.top   = element_line(color = "black", linewidth = 0.5),
    axis.minor.ticks.y.right  = element_line(color = "black", linewidth = 0.5),
    axis.text.x.top   = element_blank(),
    axis.text.y.right = element_blank()
  )

# --- Colors & linetypes ---
custom_colors <- c(
  "BM"              = "#882EE6",
  "BMDecay"         = "#000000",
  "Evict"           = "#ff3333",
  "BMDecay t=5%"    = "#E69F00",
  "BMDecay t=10%"   = "#56B4E9",
  "BMDecay t=20%"   = "#009E73",
  "Evict t=5%"      = "#D55E00",
  "Evict t=10%"     = "#0072B2",
  "Evict t=20%"     = "#006633"
)

custom_lty <- c(
  "BM"              = "solid",
  "BMDecay"         = "solid",
  "Evict"           = "solid",
  "BMDecay t=5%"    = "solid",
  "BMDecay t=10%"   = "solid",
  "BMDecay t=20%"   = "solid",
  "Evict t=5%"      = "solid",
  "Evict t=10%"     = "solid",
  "Evict t=20%"     = "solid"
)

# --- Common columns ---
common_cols <- c("time", "n_sent", "n_recv", "avgRecv", "avgByzRecv", "pByzRecv", "avgByzN")

# --- Helper: read one file ---
read_file <- function(fname, strategy_label, f_pct, run) {
  if (!file.exists(fname)) {
    cat("Warning: file not found:", fname, "\n")
    return(NULL)
  }
  d <- read.table(fname, header = TRUE)
  d <- d[, intersect(names(d), common_cols), drop = FALSE]
  d$time     <- as.integer(d$time)
  d$strategy <- strategy_label
  d$f_pct    <- f_pct
  d$run      <- run

  #filter time between 9500 and 10500
  #d <- d %>% filter(time >= 9500 & time <= 11500)

  d
}


# --- Load base strategies: BM, BMDecay, Evict (no trusted) ---
load_base <- function() {
  print("Loading base strategies...")
  strats <- list(
    bm    = list(key = "bm",    label = "BM",     has_budget = TRUE),
    decay = list(key = "decay", label = "BMDecay", has_budget = TRUE),
    evict = list(key = "evict", label = "Evict",   has_budget = TRUE)
  )
  df <- data.frame()
  for (s in strats) {
    for (f_pct in faulty_pcts) {
      faulty_count <- as.integer(nodes * f_pct / 100)
      for (run in 1:nruns) {
        fname <- if (s$has_budget) {
          file.path(results_dir,
                    sprintf("%s-N%d-v%d-f%d-y%g-run%d",
                            s$key, nodes, view, faulty_count, budget, run))
        } else {
          file.path(results_dir,
                    sprintf("%s-N%d-v%d-f%d-run%d",
                            s$key, nodes, view, faulty_count, run))
        }
        #print(paste("Reading:", fname))
        d <- read_file(fname, s$label, f_pct, run)
        if (!is.null(d)) df <- rbind(df, d)
      }
    }
  }
  df
}

# --- Load trusted variants for a given base strategy ---
# strat_key: "decay" or "evict"
# label_prefix: "BMDecay" or "Evict"
# has_budget: TRUE 
load_trusted <- function(strat_key, label_prefix, has_budget, eviction_rate = 0.0) {
  print("Loading trusted")
  eviction_tag <- if (eviction_rate != 0.0) sprintf("-e%g", eviction_rate) else ""
  df <- data.frame()
  for (t_pct in trusted_pcts) {
    t_count <- as.integer(nodes * t_pct / 100)
    for (f_pct in faulty_pcts) {
      faulty_count <- as.integer(nodes * f_pct / 100)
      for (run in 1:nruns) {
        fname <- if (has_budget) {
          file.path(merge_dir,
                    sprintf("%s-N%d-v%d-f%d-y%.1g-x%d%s-run%d",
                            strat_key, nodes, view, faulty_count, budget, t_count, eviction_tag, run))
        } else {
          file.path(results_dir,
                    sprintf("%s-N%d-v%d-f%d-x%d%s-run%d",
                            strat_key, nodes, view, faulty_count, t_count, eviction_tag, run))
        }
        label <- paste0(label_prefix, " t=", t_pct, "%")
        d <- read_file(fname, label, f_pct, run)
        if (!is.null(d)) df <- rbind(df, d)
      }
    }
  }
  df
}

# --- Prepare and average data ---
prepare <- function(df, level_order) {
  df$propByz <- df$avgByzN / view
  avg <- df %>%
    group_by(strategy, f_pct, time) %>%
    summarise(propByz = mean(propByz), .groups = "drop") %>%
    filter(time %% 10 == 0)
  present <- intersect(level_order, unique(avg$strategy))
  avg$strategy <- factor(avg$strategy, levels = present)
  avg
}

# --- Plotting function ---
byz_plot <- function(data, f, colors, ltys, show_legend = TRUE, show_y_title = TRUE) {
  optimal <- f / 100
  ggplot(data, aes(x = time, y = propByz, color = strategy,
                   linetype = strategy, group = strategy)) +
    geom_hline(yintercept = optimal, linetype = "dashed", color = "gray50") +
    geom_line(linewidth = line_size) +
    scale_color_manual(values = colors, drop = FALSE) +
    scale_linetype_manual(values = ltys, drop = FALSE) +
    labs(
      x = expression(bold("Rounds")),
      y = if (show_y_title) expression(bold("Proportion of Byz. samp.")) else NULL
    ) +
    coord_cartesian(ylim = c(0, 1)) +
    scale_x_continuous(breaks = c(0, 5000, 10000, 15000, 20000),
                       labels = c("0", "5K", "10K", "15K", "20K"),
                       sec.axis = dup_axis(labels = NULL, name = NULL)) +
    scale_y_continuous(breaks = seq(0, 1, by = 0.2),
                       minor_breaks = seq(0, 1, by = 0.1),
                       sec.axis = dup_axis(labels = NULL, name = NULL)) +
    mytheme +
    theme(legend.position = if (show_legend) c(0.5, 0.75) else "none") +
    guides(color    = guide_legend(ncol = 1),
           linetype = guide_legend(ncol = 2))
}

make_grid <- function(avg_data, colors, ltys, outfile) {
  plots <- list()
  for (i in seq_along(faulty_pcts)) {
    f   <- faulty_pcts[i]
    sub <- avg_data %>% filter(f_pct == f)
    plots[[i]] <- byz_plot(sub, f, colors, ltys,
                           show_legend  = (i == 1),
                           show_y_title = (i == 1))
  }
  dir.create("results", showWarnings = FALSE)
  pdf(outfile, width = width, height = height)
  grid.arrange(grobs = plots, nrow = 1, ncol = 4)
  dev.off()
  cat("Saved to:", outfile, "\n")
}

# ============================================================
# Figure 1: BM + BMDecay + Evict
# ============================================================
base_df    <- load_base()
fig1_order <- c("BM", "BMDecay", "Evict")
fig1_data  <- prepare(base_df, fig1_order)

fig1_colors <- custom_colors[fig1_order]
fig1_ltys   <- custom_lty[fig1_order]

make_grid(fig1_data, fig1_colors, fig1_ltys,
          sprintf("results/fig1_bm_bmdecay_evict_%gKB_%s.pdf", budget, merge_subdir))

# ============================================================
# Figure 2: BM + BMDecay + BMDecay t=5%/10%/20%
# ============================================================
bmdecay_trusted_df <- load_trusted("decay", "BMDecay", has_budget = TRUE)
fig2_order <- c("BM", "BMDecay", paste0("BMDecay t=", trusted_pcts, "%"))
fig2_data  <- prepare(rbind(base_df[base_df$strategy %in% c("BM","BMDecay"), ], bmdecay_trusted_df),
                      fig2_order)

fig2_colors <- custom_colors[fig2_order]
fig2_ltys   <- custom_lty[fig2_order]

make_grid(fig2_data, fig2_colors, fig2_ltys,
          sprintf("results/fig2_bm_bmdecay_merge_%gKB_%s.pdf", budget, merge_subdir))

# ============================================================
# Figure 3: BMDecay t=% vs Evict t=%
# ============================================================
#evict_trusted_df <- load_trusted("evict", "Evict", has_budget = TRUE, eviction_rate = eviction_rate)
#fig3_order <- c(paste0("BMDecay t=", trusted_pcts, "%"),
 #               paste0("Evict t=",   trusted_pcts, "%"))
#fig3_data  <- prepare(rbind(bmdecay_trusted_df, evict_trusted_df), fig3_order)

evict_trusted_df <- load_trusted("evict", "Evict", has_budget = TRUE, eviction_rate = eviction_rate)
fig3_base <- base_df[base_df$strategy %in% c("BMDecay", "Evict"), ]
fig3_order <- c("BMDecay", paste0("BMDecay t=", trusted_pcts, "%"),
               "Evict", paste0("Evict t=",   trusted_pcts, "%"))
fig3_data  <- prepare(rbind(fig3_base, bmdecay_trusted_df, evict_trusted_df), fig3_order)

fig3_colors <- custom_colors[fig3_order]
fig3_ltys   <- custom_lty[fig3_order]

make_grid(fig3_data, fig3_colors, fig3_ltys,
          sprintf("results/fig3_bmdecay_merge_vs_evict_merge_%gKB_%s.pdf", budget, merge_subdir))

# ============================================================
# Figure 4: BM + BMDecay + Evict t=%
# ============================================================
fig4_order <- c("BM", "BMDecay", paste0("Evict t=", trusted_pcts, "%"))
fig4_data  <- prepare(rbind(base_df[base_df$strategy %in% c("BM","BMDecay"), ], evict_trusted_df),
                      fig4_order)

fig4_colors <- custom_colors[fig4_order]
fig4_ltys   <- custom_lty[fig4_order]

make_grid(fig4_data, fig4_colors, fig4_ltys,
          sprintf("results/fig4_bm_bmdecay_evict_merge_%gKB_%s.pdf", budget, merge_subdir))

quit()

# --- Gain helpers ---
# Compute relative gain: (propByz_baseline - propByz_trusted) / propByz_baseline
prepare_gain <- function(base_avg, trusted_avg, trusted_labels) {
  gain_df <- data.frame()
  for (lbl in trusted_labels) {
    t_sub  <- trusted_avg %>% filter(strategy == lbl)
    merged <- inner_join(
      base_avg %>% select(f_pct, time, propByz_base = propByz),
      t_sub    %>% select(f_pct, time, strategy, propByz),
      by = c("f_pct", "time")
    )
    merged$gain <- (merged$propByz_base - merged$propByz) / merged$propByz_base
    gain_df <- rbind(gain_df, merged %>% select(f_pct, time, strategy, gain))
  }
  gain_df$strategy <- factor(gain_df$strategy, levels = trusted_labels)
  gain_df
}

gain_plot <- function(data, f, colors, ltys, show_legend = TRUE, show_y_title = TRUE) {
  ggplot(data, aes(x = time, y = gain, color = strategy,
                   linetype = strategy, group = strategy)) +
    geom_hline(yintercept = 0, linetype = "dashed", color = "gray50") +
    geom_line(linewidth = line_size) +
    scale_color_manual(values = colors, drop = FALSE) +
    scale_linetype_manual(values = ltys, drop = FALSE) +
    labs(
      x = expression(bold("Rounds")),
      y = if (show_y_title) expression(bold("Relative gain")) else NULL
    ) +
    coord_cartesian(ylim = c(-0.5, 0.5)) +
    scale_x_continuous(breaks = c(0, 5000, 10000, 15000, 20000),
                       labels = c("0", "5K", "10K", "15K", "20K"),
                       sec.axis = dup_axis(labels = NULL, name = NULL)) +
    scale_y_continuous(breaks = seq(-1, 1, by = 0.2),
                       minor_breaks = seq(-1, 1, by = 0.1),
                       sec.axis = dup_axis(labels = NULL, name = NULL)) +
    mytheme +
    theme(legend.position = if (show_legend) c(0.5, 0.75) else "none") +
    guides(color    = guide_legend(ncol = 1),
           linetype = guide_legend(ncol = 1))
}



make_gain_grid <- function(gain_data, colors, ltys, outfile) {
  plots <- list()
  for (i in seq_along(faulty_pcts)) {
    f   <- faulty_pcts[i]
    sub <- gain_data %>% filter(f_pct == f)
    plots[[i]] <- gain_plot(sub, f, colors, ltys,
                            show_legend  = (i == 1),
                            show_y_title = (i == 1))
  }
  dir.create("results", showWarnings = FALSE)
  pdf(outfile, width = width, height = height)
  grid.arrange(grobs = plots, nrow = 1, ncol = 4)
  dev.off()
  cat("Saved to:", outfile, "\n")
}

# ============================================================
# Figure 4: gain of merging for BMDecay
# ============================================================
bmdecay_base_avg    <- prepare(base_df[base_df$strategy == "BMDecay", ], "BMDecay")
bmdecay_trusted_avg <- prepare(bmdecay_trusted_df, paste0("BMDecay t=", trusted_pcts, "%"))

fig4_labels <- paste0("BMDecay t=", trusted_pcts, "%")
fig4_gain   <- prepare_gain(bmdecay_base_avg, bmdecay_trusted_avg, fig4_labels)

fig4_colors <- custom_colors[fig4_labels]
fig4_ltys   <- custom_lty[fig4_labels]

make_gain_grid(fig4_gain, fig4_colors, fig4_ltys,
               sprintf("results/fig4_bmdecay_merge_gain_%gKB_%s.pdf", budget, merge_subdir))

# ============================================================
# Figure 5: gain of merging for Evict
# ============================================================
evict_base_avg    <- prepare(base_df[base_df$strategy == "Evict", ], "Evict")
evict_trusted_avg <- prepare(evict_trusted_df, paste0("Evict t=", trusted_pcts, "%"))

fig5_labels <- paste0("Evict t=", trusted_pcts, "%")
fig5_gain   <- prepare_gain(evict_base_avg, evict_trusted_avg, fig5_labels)

fig5_colors <- custom_colors[fig5_labels]
fig5_ltys   <- custom_lty[fig5_labels]

make_gain_grid(fig5_gain, fig5_colors, fig5_ltys,
               sprintf("results/fig5_evict_merge_gain_%gKB_%s.pdf", budget, merge_subdir))
