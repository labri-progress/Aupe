#!/usr/bin/env Rscript
args = commandArgs(trailingOnly=TRUE)

# Rscript allstrat.r 10
library(ggplot2)
library(dplyr)
library(tidyr)

# 0. Loading
N=10000
v=160

sup = as.integer(args[1])

filename=paste("../results/m=", sup, "/N=", N, 
" v=", v, "/compoVIEW", sep="")
data <- read.table(filename, header = TRUE, sep = "", stringsAsFactors = FALSE)

# 1. Cleaning
data$faulty= data$faulty/100
data$resilience= data$resilience/100
k=1000
s=10

data = data %>% 
  filter(! dim %in% c("aupe"))
#data$Strat = paste(data$dim, "(t=",data$trusty,"%)", sep="")
data$Strat <- ifelse(data$dim != "Basalt" & data$dim != "Brahms", 
                     paste(data$dim, "(t=", data$trusty, "%)", sep=""), 
                     data$dim)


unique(data$Strat)

# Define trust levels
trust_levels <- c(0, 1, 10)

custom_linetypes <- c()
custom_linetypes[paste("cms(", s, ",", k, ")", sep="")] = "solid"
custom_linetypes[paste("serie(", s, ",", k, ")", sep="")] = "dotted"
custom_linetypes["omn"] = "dashed"
custom_linetypes["Basalt"] = "twodash"
custom_linetypes["Brahms"] = "longdash"

omn_colors <- c("#006600", "#2CA02C", "#33FF99")
cms_colors <- c("#FF3399", "#CC6666", "#FF0033")
serie_colors <- c("#882EE6", "#C42EE6", "#AB6FEB")

custom_colors <- c("Basalt" = "#3399FF", "Brahms" = "#FF7F00")

for (i in seq_along(trust_levels)) {
  custom_colors[paste("omn(t=", trust_levels[i], "%)", sep = "")] <- omn_colors[i]
}

for (i in seq_along(trust_levels)) {
  custom_colors[paste("cms(", s, ",", k, ")(t=", trust_levels[i], "%)", sep = "")] <- cms_colors[i]
}

for (i in seq_along(trust_levels)) {
  custom_colors[paste("serie(", s, ",", k, ")(t=", trust_levels[i], "%)", sep = "")] <- serie_colors[i]
}

custom_colors

levels = unique(data$Strat)[order(decreasing = c(FALSE),unique(data$Strat))]
levels
data$Strat <- factor(data$Strat, levels = levels)
data <- data[(data$Strat %in% levels), ]
numb_col = length(levels)/3

line_size <- 0.5
point_size <- 1.5
create_plot <- function(df) {
  y_breaks = c(0.0, 0.2, 0.4, 0.6, 0.8, 1.0)
  x_breaks = c(0.0, 0.1, 0.2, 0.3, 0.4, 0.5)
  if (length(intersect(x_breaks, unique(df$faulty))) < 3){
    x_breaks = append(0.0,unique(df$faulty))
  }
  print(x_breaks)
  ggplot(df, aes(x = faulty, y = resilience, color = Strat, linetype = dim)) +
    geom_point(size=point_size) +
    geom_line(linewidth=line_size) +
    geom_abline(intercept = 0, slope = 1, linetype = "dashed", color = "black") +  # Add y = x line
    scale_color_manual(values = custom_colors) +
    scale_linetype_manual(values = custom_linetypes, guide="none") +
    labs(title = paste("Resilience of strategies depending on f
     N=", N," v=", v," F=10 sm=100 m=", sup, sep=""), color=NULL,
      x = "Proportion of Byzantine nodes", 
      y = "Proportion of Byzantine samples") +
    coord_cartesian(xlim = c(0.07, 0.5), ylim = c(0, 1))+
    scale_x_continuous(breaks = x_breaks) +
    scale_y_continuous(breaks = y_breaks) +
    theme(
      panel.grid.major = element_blank(),  # Remove major gridlines
      panel.grid.minor = element_blank(),  # Remove minor gridlines
      panel.background = element_rect("white"),
      panel.border = element_rect(colour = "black", size=1,
       fill = NA),  # Optional: add border
      legend.position = c(0.77, 0.17),
      legend.spacing.y = unit(0.005, "cm"),
      text = element_text(size = 12, color="black"),
      axis.title.x = element_text(size = 14, face = "bold"),  # Increase x-axis title size
      axis.title.y = element_text(size = 14, face = "bold"),  # Increase y-axis title size
      axis.text.x = element_text(size = 14),  # Increase x-axis text size
      axis.text.y = element_text(size = 14),  # Increase y-axis text size
      plot.title = element_text(size = 14, face = "bold"),  # Increase plot title size
      legend.text = element_text(size = 11),  # Increase legend text size
      legend.title = element_blank(), 
      axis.ticks = element_line(color = "black", size=1), 
    )+
   guides(color=guide_legend(ncol=numb_col))
}

# 2. Plots
ratio <- 16 / 9
width <- 8   # largeur en pouces
height <- width / ratio
pdf(paste(filename, ".pdf", sep=""), width = width, height = height)
create_plot(data)
  
dev.off()