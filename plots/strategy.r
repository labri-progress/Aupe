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

#Filter
data = data[data$comment %in% c("RAS"), ]

custom_colors <- c("Basalt" = "#2CA02C", "Brahms" = "#FF7F00",
"Aupe(t=0%)" = "#C77CFF", "Aupe(t=100%)" = "#00BFC4", "Aupe(t=1%)"="yellow", "Aupe(t=5%)"="pink", "Aupe(t=10%)"="chocolate1", 
    "Aupe(t=20%)"="darkgreen", "Aupe(t=30%)"="black", "AupeGlobal" = "red")

levels=c("Aupe(t=0%)", "Aupe(t=30%)", "Aupe(t=100%)", 
    "Basalt","Brahms")

data$Strat <- factor(data$Strat, levels = levels)
data

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
    # N=", N," v=", v," F=10 sm=100 rho=",
    #rho_value, sep=""), color=NULL,
      x = "Proportion of Byzantine nodes", 
      y = "Proportion of Byzantine samples") +
    coord_cartesian(xlim = c(0.07, 0.5), ylim = c(0, 1))+
    scale_x_continuous(breaks = x_breaks) +
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
      axis.ticks = element_line(color = "black", size=1), 
    )+
   guides(color=guide_legend(ncol=2))
}

# 2. Plots
ratio <- 16 / 9
width <- 8   # largeur en pouces
height <- width / ratio
pdf("resilience_plots.pdf", width = width, height = height)
for (rho_value in unique(data$rho)) {
  plot_data <- data %>% filter(rho == rho_value)
  print(rho_value)
  p <- create_plot(plot_data, rho_value)
  print(p)
}
dev.off()