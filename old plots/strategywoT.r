#!/usr/bin/env Rscript
args = commandArgs(trailingOnly=TRUE)
#Rscript strategy.r 10000
library(ggplot2)
library(dplyr)
library(tidyr)

# 0. Loading
N=as.numeric(args[1])
if (N==10000){
  v=160
}else{
  v=100
}

filename=paste("../results/N=", N, 
" v=", v, "/dsncompoVIEW", sep="")
data <- read.table(filename, header = TRUE, sep = "", stringsAsFactors = FALSE)

# 1. Cleaning
data$faulty= data$faulty/100
data$resilience= data$resilience/100
data$Strat <- gsub("aupe-merge", "AupeMerge", data$Strat)
data$Strat <- gsub("aupe-global", "AupeGlobal", data$Strat)
data$Strat <- gsub("basalt", "Basalt", data$Strat)
data$Strat <- gsub("brahms", "Brahms", data$Strat)
data$Strat <- gsub("aupe", "Aupe", data$Strat)

#Filter
#data = data[data$comment %in% c("RAS"), ]
data

custom_colors <- c("Basalt" = "#2CA02C", "Brahms" = "#FF7F00",
"Aupe" = "#C77CFF", "AupeMerge" = "#00BFC4", #"Optimal"= "black", 
"AupeGlobal" = "red", "Aupewithpond" = "black", "Aupewopond" = "chocolate")

line_size <- 1
point_size <- 1.5
create_plot <- function(df, rho_value) {
  x_breaks = c(0.0, 0.1, 0.2, 0.3, 0.4, 0.5)
  if (length(intersect(x_breaks, unique(df$faulty))) < 3){
    x_breaks = append(0.0,unique(df$faulty))
  }
  print(x_breaks)
  ggplot(df, aes(x = faulty, y = resilience, color = Strat)) +
    geom_point(size=point_size) +
    geom_line(linewidth=line_size) +
    geom_abline(intercept = 0, slope = 1, linetype = "dashed", color = "black") +  # Add y = x line
    geom_abline(intercept = 0, slope = 0.75, color = "yellow", linetype = "dashed") +  # Add y = 0.75x line
    geom_abline(intercept = 0, slope = 1.25, color = "yellow", linetype = "dashed") +   # Add y = 1.25x line
    scale_color_manual(values = custom_colors) +
    labs(title = paste("Resilience of strategies depending on f
     N=", N," v=", v," F=10 sm=100 rho=",
    rho_value, sep=""), color=NULL,
      x = "Proportion of Byzantine nodes", 
      y = "Proportion of Byzantine samples") +
    coord_cartesian(ylim = c(0, 1))+
    scale_x_continuous(breaks = x_breaks) +
    scale_y_continuous(breaks = c(0.0, 0.2, 0.4, 0.6, 0.8, 1.0)) +
    theme(
      panel.grid.major = element_blank(),  # Remove major gridlines
      panel.grid.minor = element_blank(),  # Remove minor gridlines
      panel.background = element_rect("white"),
      panel.border = element_rect(colour = "black", size=1,
       fill = NA),  # Optional: add border
      legend.position = c(0.85, 0.2),
      legend.spacing.y = unit(0.005, "cm"),
      text = element_text(size = 12, color="black"),
      axis.title.x = element_text(size = 14, face = "bold"),  # Increase x-axis title size
      axis.title.y = element_text(size = 14, face = "bold"),  # Increase y-axis title size
      axis.text.x = element_text(size = 14),  # Increase x-axis text size
      axis.text.y = element_text(size = 14),  # Increase y-axis text size
      plot.title = element_text(size = 14, face = "bold"),  # Increase plot title size
      legend.text = element_text(size = 16),  # Increase legend text size
      legend.title = element_text(size = 14),  # Increase legend title size
       axis.ticks = element_line(color = "black", size=1), 
    )
    #guides(color = guide_legend(override.aes = list(linetype = c(0, 0, 0, 1), color = custom_colors))) # Add custom legend for y = x line
}

# 2. Plots
pdf("resilience_plots.pdf")
for (rho_value in unique(data$rho)) {
  plot_data <- data %>% filter(rho == rho_value)
  p <- create_plot(plot_data, rho_value)
  print(p)
}
dev.off()