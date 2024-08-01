#!/usr/bin/env Rscript
args = commandArgs(trailingOnly=TRUE)
#Rscript partview.r
library(ggplot2)
library(dplyr)
library(tidyr)

# 0. Loading
filename="../results/N=10000 v=160/dsnpartView" # paste("text",f, sep="")
data <- read.table(filename, header = TRUE, sep = "", stringsAsFactors = FALSE)

# 1. Cleaning
data$faulty= data$faulty/100
data$resilience= data$resilience/100
data$Strat <- gsub("aupe-merge", "aupeMerge", data$Strat)
data$Strat <- gsub("brahms", "brahms", data$Strat)
data$Strat <- gsub("aupe", "aupe", data$Strat)
custom_colors <- c("Basalt" = "#2CA02C", "Brahms" = "#FF7F00",
"Aupe" = "#C77CFF", "AupeMerge" = "#00BFC4", "Optimal"= "black")

combined_df <- data %>% mutate(Interaction = 
  interaction(Strat, part)) %>%
  mutate(Interaction = factor(Interaction, 
    levels = c("brahms.pushPart", "brahms.pullPart", "brahms.sampPart",
                                    "aupe.pushPart", "aupe.pullPart", "aupe.sampPart",
                                    "aupeMerge.pushPart", "aupeMerge.pullPart", "aupeMerge.sampPart")))


print(combined_df)

override.color=  c("chocolate1", "darkgreen", "deepskyblue", "chocolate1", "darkgreen", 
        "deepskyblue", "chocolate1", "darkgreen", "deepskyblue") #c(2, 4, 3, 2, 4, 3, 2, 4, 3)
    
override.shape <- c(16, 17, 15, 16, 17, 15, 16, 17, 15)
override.linetype <- c(1, 3, 5, 1, 3, 5, 1, 3, 5)
override.shape = override.shape[order(override.shape)]
override.linetype = override.linetype[order(override.linetype)]

line_size <- 1
point_size <- 1.5
create_plot <- function(df, rho_value) {
  ggplot(df, aes(x = faulty, y = resilience, 
    color = Interaction, linetype = Interaction, shape = Interaction)) +
    geom_point(size=point_size) +
    geom_line(linewidth=line_size) +
    geom_abline(intercept = 0, slope = 1, linetype = "dashed", color = "black") +  # Add y = x line
    scale_color_manual(values=override.color) +
    scale_linetype_manual(values=override.linetype) +
    scale_shape_manual(values=override.shape) +
    labs(title = paste("Resilience of strategies depending on 
    initial proportion of Faulty N=10000 v=160 F=10 sm=100 rho=",
    rho_value, sep=" "),
      x = "Proportion of Byzantine nodes", 
      y = "Proportion of Byzantine samples") +
    #theme_minimal()+
    scale_x_continuous(breaks = c(0.0, 0.1, 0.2, 0.3, 0.4, 0.5)) +
    scale_y_continuous(breaks = c(0.0, 0.2, 0.4, 0.6, 0.8, 1.0)) +
    theme(
      panel.grid.major = element_blank(),  # Remove major gridlines
      panel.grid.minor = element_blank(),  # Remove minor gridlines
      panel.background = element_rect("white"),
      panel.border = element_rect(colour = "black", linewidth=1,
       fill = NA),  # Optional: add border
      legend.position = c(0.75, 0.2),
      legend.box.background = element_rect(color = "gray"),
      legend.spacing.y = unit(0.005, "cm"),
      text = element_text(size = 12, color="black"),
      axis.title.x = element_text(size = 14, face = "bold"),  # Increase x-axis title size
      axis.title.y = element_text(size = 14, face = "bold"),  # Increase y-axis title size
      axis.text.x = element_text(size = 14),  # Increase x-axis text size
      axis.text.y = element_text(size = 14),  # Increase y-axis text size
      plot.title = element_text(size = 14, face = "bold"),  # Increase plot title size
      legend.text = element_text(size = 16),  # Increase legend text size
      legend.title = element_blank(),
       axis.ticks = element_line(color = "black", linewidth=1), 
    )+
    guides(color=guide_legend(ncol=2))
    #guides(color = guide_legend(override.aes = list(linetype = c(0, 0, 0, 1), color = custom_colors))) # Add custom legend for y = x line
}

# 2. Plots
pdf("partview_resilience_plots.pdf")
for (rho_value in unique(data$rho)) {
  plot_data <- combined_df %>% filter(rho == rho_value)
  p <- create_plot(plot_data, rho_value)
  print(p)
}
dev.off()