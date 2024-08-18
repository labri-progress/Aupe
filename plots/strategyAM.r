#!/usr/bin/env Rscript
args = commandArgs(trailingOnly=TRUE)
#Rscript strategy.r 10000
library(ggplot2)
library(dplyr)
library(tidyr)

# 0. Loading
N=10000
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
data$Strat <- gsub("aupe-merge", "Aupe(t=100%)", data$Strat)
data$Strat <- gsub("aupe-global", "AupeGlobal", data$Strat)
data$Strat <- gsub("basalt", "Basalt", data$Strat)
data$Strat <- gsub("brahms", "Brahms", data$Strat)
data$Strat <- gsub("aupe", "Aupe(t=0%)", data$Strat)


#data = data[data$comment %in% c("RAS"), ]
#data

custom_colors <- c("Basalt" = "#2CA02C", "Brahms" = "#FF7F00",
"Aupe(t=0%)" = "#C77CFF", "Aupe(t=100%)" = "#00BFC4", "Aupe(t=1%)"="#FFFF00", 
"Aupe(t=5%)"="#FF3399", "Aupe(t=10%)"="#996600", 
"Aupe(t=20%)"="#006600", "Aupe(t=30%)"="#000000", 
"AupeGlobal(t=100%)" = "#FF0033", "AupeGlobal(t=1%)"="#33FF99", 
"AupeGlobal(t=5%)"="#FF3399", "AupeGlobal(t=10%)"="#3399FF", 
"AupeGlobal(t=20%)"="#CC6666", "AupeGlobal(t=30%)"="#999000")

levels=c("Aupe(t=0%)", "Aupe(t=1%)", "Aupe(t=5%)", "Aupe(t=10%)",
    "Aupe(t=20%)", "Aupe(t=30%)", "Aupe(t=100%)", "Basalt", "Brahms")

data$Strat <- factor(data$Strat, levels = levels)
#data <- data[!(data$Strat %in% c("Aupe(t=1%)", "Aupe(t=5%)")), ]
kept <- c("Aupe(t=0%)", "Aupe(t=5%)", "Aupe(t=10%)",
    "Aupe(t=20%)", "Aupe(t=30%)", "Aupe(t=100%)", "Basalt", "Brahms")

data <- data[(data$Strat %in% kept), ]
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
    scale_color_manual(values = custom_colors) +
    labs(#title = paste("Resilience of strategies depending on f
     #N=", N," v=", v," F=10 sm=100 rho=",
    #rho_value, sep=""), color=NULL,
      x = "Proportion of Byzantine nodes", 
      y = "Proportion of Byzantine samples") +
    coord_cartesian(xlim = c(0.07, 0.5), ylim = c(0, 1))+
    scale_x_continuous(breaks = x_breaks) +
    coord_cartesian(ylim = c(0, 1))+
    scale_y_continuous(breaks = seq(0.0, 1.0, by=0.1)) + 
    theme(
      panel.grid.major = element_blank(),  # Remove major gridlines
      panel.grid.minor = element_blank(),  # Remove minor gridlines
      panel.background = element_rect("white"),
      panel.border = element_rect(colour = "black", size=1,
       fill = NA),  
      legend.title = element_blank(),
      legend.position = c(0.67, 0.15),
      legend.spacing.y = unit(0.005, "cm"),
      text = element_text(size = 12, color="black"),
      axis.title.x = element_text(size = 14, face = "bold"),  # Increase x-axis title size
      axis.title.y = element_text(size = 14, face = "bold"),  # Increase y-axis title size
      axis.text.x = element_text(size = 14),  # Increase x-axis text size
      axis.text.y = element_text(size = 14),  # Increase y-axis text size
      legend.text = element_text(size = 10),  # Increase legend text size
      axis.ticks = element_line(color = "black", linewidth=1), 
       
             legend.key = element_blank(),
             legend.background = element_blank(), 
    )+
   guides(color=guide_legend(nrow=2))
}

# 2. Plots
ratio <- 16 / 9
width <- 8   # largeur en pouces
height <- width / ratio

pdf("resilience_plotswithT.pdf", width = width, height = height)
for (rho_value in unique(data$rho)) {
  plot_data <- data %>% filter(rho == rho_value)
  print(rho_value)
  p <- create_plot(plot_data, rho_value)
  print(p)
}
dev.off()