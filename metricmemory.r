#!/usr/bin/env Rscript
args = commandArgs(trailingOnly=TRUE)

library(ggplot2)
library(dplyr)
library(tidyr)
library(gridExtra)

source("theme.r")
source("params.r")

nodes = 10000
v=160
force = 10
if (length(args) >= 1) {
  force = as.integer(args[1])
}
cat("nodes:", nodes, "\n")
cat("Force:", force, "\n")

#pdf_title <- paste("Different strategies, space", space, "KB, ", total, "elements in total")
faulty_plot <- function(data, y_col = "dKL", faulty, show_legend = TRUE, show_y_title = TRUE){
  x_name <- "Time steps"
  
  y_info <- y_axis_settings[[y_col]]
  y_title <- if (show_y_title) y_info$title else NULL 
  y_limits <- y_info$limits
  y_breaks <- y_info$steps
  y_pos <- y_info$pos 

  #print(paste("title:", y_title, "pos:", paste(y_pos, collapse=", "), "limits:", paste(y_limits, collapse=", "), "and breaks:", paste(y_breaks, collapse=", ")))
  p <- ggplot(data, aes(x=round, y = .data[[y_col]], color=strat, shape = strat)) 
  p <- p + geom_hline(yintercept = faulty, linetype = "dashed", color = "gray80")
  p <- p + geom_point(size=point_size) +
  geom_line(linewidth=line_size) +
  scale_color_manual(values = custom_colors) +
  scale_linetype_manual(values = custom_linetypes, guide="none") +
  labs(#title=pdf_title,
       x=x_name,
       y=y_title) +
  coord_cartesian(ylim = y_limits)+
  scale_x_continuous(breaks = x_breaks_rounds) +
  scale_y_continuous(breaks = y_breaks) +
  #theme_minimal()
  mytheme +
  theme(
      legend.position = if (show_legend) y_pos else "none") +
   guides(color=guide_legend(ncol=numb_col))
  
  return(p)
}

# Read the data
data <- read.table("analysis/results", header=TRUE)

data <- data[data$force == force, ] #& data$stream == total 
data$resilience= data$resilience/100
data$strat <- ifelse(data$strat != "KVS", 
    paste(data$strat, "-", data$budget, sep=""), 
    data$strat)
cat("Elements retenus:", length(data), "\n")
unique(data$strat)
#data
#custom_linetypes <- c()
#custom_linetypes["KVS"] = "solid"
#custom_linetypes["BM"] = "dotted"

bm_colors <- c("#3399FF", "#882EE6", "#FF0033", "#DEDC26") # F5F227")
bm_linetype <- c("dotted", "dotted", "dotted", "dotted")

custom_colors <- c("KVS" = "#000000", 
    "Basalt" = "#2CA02C", "Brahms" = "#FF7F00")
custom_linetypes <- c("KVS" = "solid")
custom_linetypes["Basalt"] = "twodash"
custom_linetypes["Brahms"] = "longdash"

for (i in seq_along(x_breaks_budget)) {
  custom_colors[paste("BM-", x_breaks_budget[i], sep = "")] <- bm_colors[i]
  custom_linetypes[paste("BM-", x_breaks_budget[i], sep = "")] <- bm_linetype[i]
}

custom_colors
custom_linetypes

levels = unique(data$strat)[
      order(decreasing = c(FALSE),unique(data$strat))]
levels

data$strat <- factor(data$strat, levels = levels)

list_items = c(1000, 2000, 3000) 


#y_axis_settings

plots_by_metric <- list()

for (y_col in y_columns) {
  metric_plots = list()
  for (faulty in list_items) {
    
    block_data <- data[data$faulty == faulty, ]
    #print(block_data)
    show_legend <- (force == 2 && faulty == 1000)
    show_y_title <- faulty == 1000

    plot <- faulty_plot(
      block_data,
      y_col = y_col,
      faulty = faulty / nodes,
      show_legend = show_legend,
      show_y_title = show_y_title
    )

    metric_plots[[length(metric_plots) + 1]] <- plot

      }
  plots_by_metric[[y_col]] <- metric_plots
}

names(plots_by_metric)


for (y_col in names(plots_by_metric)) {
  filename <- paste("results/",y_col, "_on_round_", nodes, "-", force, ".pdf", sep="")
  pdf(filename, width = width, height = height)
  grid.arrange(grobs = plots_by_metric[[y_col]], nrow = xgrid, ncol = ygrid)#, top = y_axis_settings[[y_col]]$title)
  dev.off()
}


