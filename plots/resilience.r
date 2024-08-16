#!/usr/bin/env Rscript
args = commandArgs(trailingOnly=TRUE)
k=as.integer(args[1])
library(ggplot2)
library(dplyr)
library(tidyr)
library(gridExtra)

custom_colors <- c("Basalt" = "#2CA02C", "Brahms" = "#FF7F00",
"Aupe(t=0%)" = "#C77CFF", "Aupe(t=100%)" = "#00BFC4", "Aupe(t=1%)"="#FFFF00", 
"Aupe(t=5%)"="#FF3399", "Aupe(t=10%)"="#996600", 
"Aupe(t=20%)"="darkgreen", "Aupe(t=30%)"="black", 
"AupeGlobal" = "#FF0033")
line_size <- 1
point_size <- 1.5 

partview <- function(data, component, rho_value) { 
    ggplot(data %>% filter(part == component), aes(x = faulty, 
    y = resilience, color = Strat)) +
        geom_point(size=point_size) +
        geom_line(linewidth=line_size) +
        geom_abline(intercept = 0, slope = 1, linetype = "dashed", color = "black") +  # Add y = x line
        labs(title = paste("Resilience in ", component, sep=""), #" depending on 
        #initial proportion of Faulty N=10000 v=160 F=10 sm=100 rho=",
        #rho_value, sep=" ")
          x = "Prop. of Byz. nodes", 
          y = "Prop. of Byz samples") +
        scale_x_continuous(breaks = c(0.0, 0.1, 0.2, 0.3, 0.4, 0.5)) +
        scale_y_continuous(breaks = c(0.0, 0.2, 0.4, 0.6, 0.8, 1.0)) +
        scale_color_manual(values = custom_colors) +
        #scale_linetype_manual(values = c("df1" = "solid", "df2" = "dashed", "df3" = "dotted")) +
        theme(
            panel.grid.major = element_blank(),  # Remove major gridlines
            panel.grid.minor = element_blank(),  # Remove minor gridlines
            panel.background = element_rect("white"),
            panel.border = element_rect(colour = "black", linewidth=1,
            fill = NA),  
            legend.title = element_blank(),
            legend.position = "none",
            legend.spacing.y = unit(0.005, "cm"),
            text = element_text(size = 12, color="black"),
            axis.title.x = element_text(size = 12, face = "bold"),  
            axis.title.y = element_text(size = 12, face = "bold"),  
            axis.text.x = element_text(size = 12),  
            axis.text.y = element_text(size = 12),  
            plot.title = element_text(size = 12, face = "bold"),  
            legend.background = element_rect(fill = "transparent"),
            axis.ticks = element_line(color = "black", linewidth=1), 
        )
}

partview3 <- function(data, component, rho_value) { 
    ggplot(data %>% filter(part == component), aes(x = faulty, 
    y = resilience, color = Strat)) +
        geom_point(size=point_size) +
        geom_line(linewidth=line_size) +
        geom_abline(intercept = 0, slope = 1, linetype = "dashed", color = "black") +  # Add y = x line
        labs(title = paste("Resilience in ", component, sep=""), #" depending on 
        #initial proportion of Faulty N=10000 v=160 F=10 sm=100 rho=",
        #rho_value, sep=" ")
          x = "Prop. of Byz. nodes", 
          y = "Prop. of Byz samples") +
        scale_x_continuous(breaks = c(0.0, 0.1, 0.2, 0.3, 0.4, 0.5)) +
        scale_y_continuous(breaks = c(0.0, 0.2, 0.4, 0.6, 0.8, 1.0)) +
        scale_color_manual(values = custom_colors) +
        #scale_linetype_manual(values = c("df1" = "solid", "df2" = "dashed", "df3" = "dotted")) +
        theme(
            panel.grid.major = element_blank(),  # Remove major gridlines
            panel.grid.minor = element_blank(),  # Remove minor gridlines
            panel.background = element_rect("white"),
            panel.border = element_rect(colour = "black", linewidth=1,
            fill = NA),  
            legend.title = element_blank(),
            legend.position = c(0.7, 0.1),
            legend.spacing.y = unit(0.005, "cm"),
            text = element_text(size = 12, color="black"),
            axis.title.x = element_text(size = 12, face = "bold"),  
            axis.title.y = element_text(size = 12, face = "bold"),  
            axis.text.x = element_text(size = 12),  
            axis.text.y = element_text(size = 12), 
            plot.title = element_text(size = 12, face = "bold"),  
            legend.text = element_text(size = 10),  
            #legend.title = element_text(size = 14),  # Increase legend title size
            #legend.key.height= unit(0.4, 'cm'),
                legend.key.width= unit(1, 'cm'),
            legend.background = element_rect(fill = "transparent"),
            axis.ticks = element_line(color = "black", linewidth=1), 
        )+
        guides(shape = guide_legend(override.aes = list(size = 3)))+
        guides(color=guide_legend(nrow=1))

}
# 0. Loading
filename="../results/N=10000 v=160/dsnpartView" # paste("text",f, sep="")
data <- read.table(filename, header = TRUE, sep = "", stringsAsFactors = FALSE)

# 1. Cleaning
data$faulty= data$faulty/100
data$resilience= data$resilience/100
data$Strat <- gsub("aupe-merge", "Aupe(t=100%)", data$Strat)
data$Strat <- gsub("brahms", "Brahms", data$Strat)
data$Strat <- gsub("aupe", "Aupe(t=0%)", data$Strat)

rho=k
print(colnames(data))
print(unique(data$Strat))
plot_comp1 <- partview(data, "pushPart", rho)
plot_comp2 <- partview(data, "pullPart", rho)
plot_comp3 <- partview3(data, "sampPart", rho)

pdf("partview_resilience_plots.pdf")
grid.arrange(plot_comp1, plot_comp2, plot_comp3, ncol = 1)

dev.off()

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
