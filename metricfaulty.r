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
faulty_plot <- function(data, y_col = "dKL"){
  x_name <- "Proportion of Byzantine nodes"
  
  y_info <- y_axis_settings[[y_col]]
  y_title <- y_info$title
  y_limits <- y_info$limits
  y_breaks <- y_info$steps
  y_pos <- y_info$pos 

  #print(paste("title:", y_title, "pos:", paste(y_pos, collapse=", "), "limits:", paste(y_limits, collapse=", "), "and breaks:", paste(y_breaks, collapse=", ")))
  p <- ggplot(data, aes(x=faulty, y = .data[[y_col]], color=strat, shape = strat)) 
  p <- p + geom_abline(intercept = 0, slope = 1, linetype = "dashed", color = "gray80")
  p <- p + geom_point(size=point_size) +
  geom_line(linewidth=line_size) +
  scale_color_manual(values = custom_colors) +
  scale_shape_manual(values = custom_scales) +
  scale_linetype_manual(values = custom_linetypes, guide="none") +
  labs(#title=pdf_title,
       x=x_name,
       y=y_title) +
  coord_cartesian(ylim = y_limits)+
  scale_x_continuous(breaks = x_breaks_faulty) +
  scale_y_continuous(breaks = y_breaks) +
  #theme_minimal()
  mytheme +
  theme(
      legend.position = y_pos) +
   guides(color=guide_legend(ncol=numb_col))
  
  return(p)
}

mytheme <- theme(
  panel.grid.major = element_blank(), 
  panel.grid.minor = element_blank(), 
  panel.background = element_rect("white"),
  panel.border = element_rect(colour = "black", linewidth=1,
    fill = NA),  
  legend.spacing.y = unit(0.005, "cm"),
  text = element_text(size = 14, color="black"),
  axis.title.x = element_text(size = 14, face = "bold"),  
  axis.title.y = element_text(size = 14, face = "bold"),  
  axis.text.x = element_text(size = 14, face = "bold"),   
  axis.text.y = element_text(size = 14, face = "bold"),   
  plot.title = element_text(size = 14, face = "bold"), 
  legend.text = element_text(size = 14, face = "bold"), 
  legend.title = element_blank(), 
  legend.background = element_rect(fill = "transparent", colour = NA),
  legend.box.background = element_rect(fill = "transparent", colour = NA),
  axis.ticks = element_line(color = "black", linewidth=1), 
)

# Read the data
data <- read.table("analysis/results", header=TRUE)

roundMAX <- 200
data <- data[data$force == force& data$round == roundMAX, ]
data$resilience= data$resilience/100
data$faulty <- data$faulty / nodes
data$strat <- ifelse(data$strat != "Aupe" & data$strat != "Basalt" & data$strat != "Brahms", 
    paste(data$strat, "-", data$budget, sep=""), 
    data$strat)
cat("Elements retenus:", length(data), "\n")
unique(data$strat)
data

bm_colors <- c("#273FF5", "#F527E4", "#3399FF", "#882EE6", "#FF0033", "#DEDC26") # F5F227")
bm_linetype <- c("dotted", "dotted", "dotted", "dotted", "dotted", "dotted")
bm_scales <- c(0, 1, 2, 3, 6, 8)

custom_colors <- c("Aupe" = "#000000", 
    "Basalt" = "#2CA02C", "Brahms" = "#FF7F00")
custom_linetypes <- c("Aupe" = "solid")
custom_linetypes["Basalt"] = "twodash"
custom_linetypes["Brahms"] = "longdash"

custom_scales <- c("Aupe" = 7, "Basalt" = 4, "Brahms" = 5)

for (i in seq_along(x_breaks_budget)) {
  custom_colors[paste("BM-", x_breaks_budget[i], sep = "")] <- bm_colors[i]
  custom_linetypes[paste("BM-", x_breaks_budget[i], sep = "")] <- bm_linetype[i]
  custom_scales[paste("BM-", x_breaks_budget[i], sep = "")] <- bm_scales[i]
}

custom_colors
custom_linetypes

levels = c("Aupe", "Basalt", "Brahms", "BM-1", "BM-5", "BM-10", "BM-20", "BM-30", "BM-40") #unique(data$strat)[order(decreasing = c(FALSE),unique(data$strat))]

data$strat <- factor(data$strat, levels = levels)
#y_axis_settings

plots_by_metric <- list()

for (y_col in y_columns) {
  metric_plots = list()

  plot <- faulty_plot(
    data,
    y_col = y_col
  )

  metric_plots[[length(metric_plots) + 1]] <- plot

  plots_by_metric[[y_col]] <- metric_plots
}

names(plots_by_metric)

ratio <- 16 / 9 
width <- 8
height <- width / ratio

#grid settings
xgrid <- 1
ygrid <- 1

for (y_col in names(plots_by_metric)) {
  filename <- paste("results/",y_col, "_on_faulty_", nodes, "-", force, ".pdf", sep="")
  pdf(filename, width = width, height = height)
  grid.arrange(grobs = plots_by_metric[[y_col]], nrow = xgrid, ncol = ygrid)#, top = y_axis_settings[[y_col]]$title)
  dev.off()
}


