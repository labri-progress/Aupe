#!/usr/bin/env Rscript
args = commandArgs(trailingOnly=TRUE)
#Rscript strategy.r
library(ggplot2)
library(dplyr)
library(tidyr)

filename="../results/N=10000 v=160/dsncompoVIEW" # paste("text",f, sep="")
data <- read.table(filename, header = TRUE, sep = "", stringsAsFactors = FALSE)

# Split the Strat column into two separate columns: Strat and rho
data <- data %>%
  separate(Strat, into = c("Strat", "rho"), sep = "(?<=\\D)(?=rho)")

data$Strat <- gsub("aupe-merge", "aupeMerge", data$Strat)

custom_colors <- c("basalt" = "#2CA02C", "brahms" = "#FF7F00",
"aupe" = "#C77CFF", "aupeMerge" = "#00BFC4", "optimal"= "black")

create_plot <- function(df, rho_value) {
  ggplot(df, aes(x = faulty, y = resilience, color = Strat)) +
    geom_point() +
    geom_line() +
    geom_abline(intercept = 0, slope = 1, linetype = "dashed", color = "black") +  # Add y = x line
    scale_color_manual(values = custom_colors) +
    labs(title = paste("Resilience of strategies depending on 
    initial proportion of Faulty N=10000 v=160 F=10 sm=100 rho=",
    rho_value, sep=" "), color=NULL,
      x = "Faulty (%)", y = "Resilience(%)") +
    theme_minimal()+
    scale_x_continuous(breaks = unique(data$faulty)) +
    scale_y_continuous(breaks = seq(0,100, 10)) 
    #guides(color = guide_legend(override.aes = list(linetype = c(0, 0, 0, 1), color = custom_colors))) # Add custom legend for y = x line
}

# Create and save the plots to a multi-page PDF
pdf("resilience_plots.pdf")
for (rho_value in unique(data$rho)) {
  plot_data <- data %>% filter(rho == rho_value)
  p <- create_plot(plot_data, rho_value)
  print(p)
}
dev.off()