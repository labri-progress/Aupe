#!/usr/bin/env Rscript
# Usage: Rscript plot_resilience_decay.r <budget> <p_merge>
# Example: Rscript plot_resilience_decay.r 1 10
#
# Resilience curve: steady-state proportion of Byzantine samples
# as a function of the Byzantine proportion in the system.
#
# X axis : Byzantine proportion in the system (faulty_pct / 100)
# Y axis : steady-state avgByzSamp / view
# Lines  : different trusted node percentages (t_pct = 0, 5, 10, 20, 30)
# Ref    : y = x  (no debiasing / optimal case)
#
# Data is read from results_merge/ with format:
#   decay-{nodes}-{view}-{faulty_count}-{t_count}-{p_merge}-{budget}-run{run}
#
# Output: results/resilience_curve_b<budget>_p<p_merge>.pdf

args <- commandArgs(trailingOnly = TRUE)

library(ggplot2)
library(dplyr)
# Rscript plot_resilience_decay.r 1 10
# ── Parameters ────────────────────────────────────────────────────────────────
budget       <- as.integer(args[1]) #as.integer(args[1])   # e.g. 1
p_merge      <- as.integer(args[2])   # e.g. 10

nodes        <- 1000
view         <- 20 # 216
nruns        <- 2
strategy     <- "decay"
results_dir  <- "results_merge"

faulty_pcts    <- seq(10, 40, by = 2) #c(10, 20, 30)
trusted_pcts   <- c(0, 5, 10, 20) #, 30)
trusted_counts <- as.integer(nodes * trusted_pcts / 100)

# Fraction of final timesteps used to estimate steady state
ss_frac <- 0.2

# ── Style ─────────────────────────────────────────────────────────────────────
line_size  <- 0.7
point_size <- 2.5
width      <- 7
height     <- 3.5

custom_colors <- c("0"  = "#000000",
                   "5"  = "#E69F00",
                   "10" = "#56B4E9",
                   "20" = "#009E73",
                   "30" = "#D55E00")

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
  axis.text.x           = element_text(size = 12, face = "bold"),
  axis.text.y           = element_text(size = 12, face = "bold"),
  plot.title            = element_text(size = 12, face = "bold"),
  legend.text           = element_text(size = 11, face = "bold"),
  legend.title          = element_text(size = 11, face = "bold"),
  legend.background     = element_rect(fill = "transparent", colour = NA),
  legend.box.background = element_rect(fill = "transparent", colour = NA),
  axis.ticks            = element_line(color = "black", linewidth = 1)
)

# ── Read data and compute steady-state ────────────────────────────────────────

summary_data <- data.frame()

for (f_pct in faulty_pcts) {
  f_count <- as.integer(nodes * f_pct / 100)

  for (ti in seq_along(trusted_pcts)) {
    t_pct   <- trusted_pcts[ti]
    t_count <- trusted_counts[ti]

    for (run in 1:nruns) {
      fname <- file.path(results_dir,
                         sprintf("%s-%d-%d-%d-%d-%d-%d-run%d",
                                 strategy, nodes, view, f_count,
                                 t_count, p_merge, budget, run))
      if (!file.exists(fname)) {
        cat("Warning: file not found:", fname, "\n"); next
      }
      d <- read.table(fname, header = TRUE)
      d$time <- as.integer(d$time)

      # Steady-state: average over last ss_frac of timesteps
      n_ss   <- max(1, floor(nrow(d) * ss_frac))
      d_ss   <- tail(d, n_ss)

      summary_data <- rbind(summary_data, data.frame(
        f_pct  = f_pct,
        t_pct  = t_pct,
        run    = run,
        res = mean(d_ss$avgByzSamp / view, na.rm = TRUE)
      ))
    }
  }
}

if (nrow(summary_data) == 0) {
  cat("No data found. Check results_dir and file naming.\n"); quit(status = 1)
}

# Average over runs
avg_ss <- summary_data %>%
  group_by(f_pct, t_pct) %>%
  summarise(res = mean(res, na.rm = TRUE), .groups = "drop")

avg_ss$byz_prop <- avg_ss$f_pct / 100
avg_ss$t_pct_f  <- factor(avg_ss$t_pct)

# ── Plot ──────────────────────────────────────────────────────────────────────
faulty_pcts2    <- seq(10, 40, by = 10) #c(10, 20, 30)
p <- ggplot(avg_ss, aes(x = byz_prop, y = res,
                        color = t_pct_f, group = t_pct_f)) +
  # Reference line: y = x (no debiasing)
  geom_abline(slope = 1, intercept = 0, linetype = "dashed", color = "gray50") +
  geom_line(linewidth = line_size) +
  geom_point(size = point_size) +
  scale_color_manual(values = custom_colors,
                     labels = ifelse(names(custom_colors) == "0",
                                     "t=0%", paste0("t=", names(custom_colors), "%"))) +
  scale_x_continuous(breaks = faulty_pcts2 / 100) +
  scale_y_continuous(breaks = seq(0, 1, by = 0.2), limits = c(0, 1)) +
  labs(
    x     = expression(bold("Prop. of Byz. in system")),
    y     = expression(bold("Prop. of Byz. samples")),
    color = "Trusted %"
  ) +
  mytheme +
  theme(legend.position = c(0.25, 0.72))

# ── Save PDF ──────────────────────────────────────────────────────────────────
dir.create("results", showWarnings = FALSE)
outfile <- sprintf("results/resilience_curve_n%d_v%d_p%d_b%d.pdf", nodes, view, p_merge, budget)
pdf(outfile, width = width, height = height)
print(p)
dev.off()
cat("Saved to:", outfile, "\n")
