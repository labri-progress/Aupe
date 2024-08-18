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
#data$Strat <- gsub("aupe-merge", "Aupe(t=100%)", data$Strat)
#data$Strat <- gsub("aupe-global", "AupeGlobal", data$Strat)
data$Strat <- gsub("basalt", "Basalt", data$Strat)
data$Strat <- gsub("brahms", "Brahms", data$Strat)
data$Strat <- gsub("aupe", "Aupe-simple", data$Strat)

#Filter
#data = data[data$comment %in% c("RAS"), ]

custom_colors <- c("Basalt" = "#2CA02C", "Brahms" = "#FF7F00",
"Aupe-simple" = "#C77CFF", "Aupe(t=100%)" = "#00BFC4", "Aupe(t=1%)"="#FFFF00", 
"Aupe(t=5%)"="#FF3399", "Aupe(t=10%)"="#996600", 
"Aupe(t=20%)"="#006600", "Aupe(t=30%)"="#000000", 
"AupeGlobal(t=100%)" = "#FF0033", "AupeGlobal(t=1%)"="#33FF99", 
"AupeGlobal(t=5%)"="#FF3399", "AupeGlobal(t=10%)"="#3399FF", 
"AupeGlobal(t=20%)"="#CC6666", "AupeGlobal(t=30%)"="#999000", 
"Optimal"="black")

custom_linetypes <- c("Basalt" = "solid", "Brahms" = "solid",
"Aupe-simple" = "solid", "Optimal"="dashed")

custom_shapes <- c("Basalt" = 16, "Brahms" = 16,
"Aupe-simple" = 16,"Optimal"=NA)

levels=c("Aupe-simple", #"Aupe(t=30%)", #"Aupe(t=100%)", 
    "Basalt","Brahms", "Optimal")

data$Strat <- factor(data$Strat, levels = levels)
data <- data[(data$Strat %in% levels), ]
data

line_size <- 1
point_size <- 1.5
create_plot <- function(df) {
  x_breaks = c(0.0, 0.1, 0.2, 0.3, 0.4, 0.5)

  print(x_breaks)
  ggplot(df, aes(x = faulty, y = resilience, color = Strat, linetype = Strat, shape=Strat)) +
    geom_point(size=point_size) +
    geom_line(linewidth=line_size) +
    scale_color_manual(values = custom_colors) +
    scale_linetype_manual(values = custom_linetypes) +
    scale_shape_manual(values = custom_shapes) +
    labs(
      x = "Proportion of Byzantine nodes", 
      y = "Proportion of Byzantine samples") +
    coord_cartesian(xlim = c(0.07, 0.5), ylim = c(0, 1))+
    scale_x_continuous(breaks = x_breaks) +
    scale_y_continuous(breaks = c(0.0, 0.2, 0.4, 0.6, 0.8, 1.0)) +
    coord_cartesian(ylim = c(0, 1))+
    theme(
      panel.grid.major = element_blank(),  # Remove major gridlines
      panel.grid.minor = element_blank(),  # Remove minor gridlines
      panel.background = element_rect("white"),
      panel.border = element_rect(colour = "black", size=1,
       fill = NA),  # Optional: add border
      legend.position = c(0.7, 0.15),
      legend.spacing.y = unit(0.005, "cm"),
      text = element_text(size = 12, color="black"),
      axis.title.x = element_text(size = 14, face = "bold"),  # Increase x-axis title size
      axis.title.y = element_text(size = 14, face = "bold"),  # Increase y-axis title size
      axis.text.x = element_text(size = 14),  # Increase x-axis text size
      axis.text.y = element_text(size = 14),  # Increase y-axis text size
      plot.title = element_text(size = 14, face = "bold"),  # Increase plot title size
      legend.text = element_text(size = 16),  # Increase legend text size
      legend.title = element_blank(), 
      legend.key = element_blank(),              # Remove the background from legend keys
      legend.background = element_blank(), 
      legend.key.width= unit(1, 'cm'),
      axis.ticks = element_line(color = "black", size=1), 
    )+
   guides(color=guide_legend(ncol=2))
}

# 2. Plots
ratio <- 16 / 9
width <- 8   # largeur en pouces
height <- width / ratio

pdf("resilience_plotsNew.pdf", width = width, height = height)

p <- create_plot(data)
print(p)
dev.off()