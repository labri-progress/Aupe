#!/usr/bin/env Rscript
args = commandArgs(trailingOnly=TRUE)
#Rscript partview.r
library(ggplot2)
library(dplyr)
library(tidyr)
library(gridExtra)

custom_colors <- c("Basalt" = "#2CA02C", "Brahms" = "#FF7F00",
"Aupe(t=0%)" = "#C77CFF", "Aupe(t=100%)" = "#00BFC4", "Aupe(t=1%)"="yellow", "Aupe(t=5%)"="pink", "Aupe(t=10%)"="brown", 
    "Aupe(t=20%)"="darkgreen", "Aupe(t=30%)"="black", "AupeGlobal" = "red")

line_size <- 1
point_size <- 1.5 

partview <- function(data, component, rho_value) { 
    ggplot(data %>% filter(part == component), aes(x = faulty, 
    y = resilience, color = Strat, linetype = Strat)) +
        geom_point(size=point_size) +
        geom_line(linewidth=line_size) +
        geom_abline(intercept = 0, slope = 1, linetype = "dashed", color = "black") +  # Add y = x line
        labs(#title = paste("Resilience in ", component, sep=""), #" depending on 
        #initial proportion of Faulty N=10000 v=160 F=10 sm=100 rho=",
        #rho_value, sep=" ")
          x = "Prop. of Byz. nodes", 
          y = "Prop. of Byz Samp.") +
        scale_x_continuous(breaks = c(0.0, 0.1, 0.2, 0.3, 0.4, 0.5)) +
        #scale_y_continuous(breaks = c(0.0, 0.2, 0.4, 0.6, 0.8, 1.0)) +
        coord_cartesian(ylim = c(0, 1))+
        scale_y_continuous(breaks = seq(0.0, 1.0, by=0.2)) + 
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
    y = resilience, color = Strat, linetype = Strat)) +
        geom_point(size=point_size) +
        geom_line(linewidth=line_size) +
        geom_abline(intercept = 0, slope = 1, linetype = "dashed", color = "black") +  # Add y = x line
        labs(#title = paste("Resilience in ", component, sep=""),
          x = "Prop. of Byz. nodes", 
          y = "Prop. of Byz Samp.") +
            theme_minimal() +
            scale_y_continuous(breaks = c(0.0, 0.2, 0.4, 0.6, 0.8, 1.0)) +
            scale_color_manual(values = custom_colors) +
            theme(legend.position = c(0.7, 0.15),
                legend.title = element_blank(),
                panel.grid.major = element_blank(),  # Remove major gridlines
                panel.grid.minor = element_blank(),  # Remove minor gridlines
                panel.background = element_rect("white"),
                panel.border = element_rect(colour = "black", linewidth=1,
                fill = NA),  
                legend.spacing.y = unit(0.001, "cm"),
                text = element_text(size = 12, color="black"),
                axis.title.x = element_text(size = 13, face = "bold"),  
                axis.title.y = element_text(size = 13, face = "bold"),  
                axis.text.x = element_text(size = 13),  
                axis.text.y = element_text(size = 13), 
                plot.title = element_text(size = 13, face = "bold"),  
                legend.text = element_text(size = 10),  
                legend.key.width= unit(0.75, 'cm'),
                axis.ticks = element_line(color = "black", linewidth=1), 
            )
}

# 0. Loading
filename="../results/N=10000 v=160/dsnTpartView" # paste("text",f, sep="")
data <- read.table(filename, header = TRUE, sep = "", stringsAsFactors = FALSE)

# 1. Cleaning
data$faulty= data$faulty/100
data$resilience= data$resilience/100
data$Strat <- gsub("aupe-merge", "Aupe(t=100%)", data$Strat)
data$Strat <- gsub("brahms", "Brahms", data$Strat)
data$Strat <- gsub("aupe", "Aupe(t=0%)", data$Strat)

levels=c("Aupe(t=0%)", "Aupe(t=1%)", "Aupe(t=10%)",
    "Aupe(t=20%)", "Aupe(t=30%)", "Aupe(t=100%)", "Brahms")
data$Strat <- factor(data$Strat, levels = levels)
data = data[data$Strat %in% levels, ]
print(unique(data$Strat))
rho=1
print(paste("rho", rho, sep=""))
print(colnames(data))
plot_comp1 <- partview(data, "pushPart", rho)
plot_comp2 <- partview(data, "pullPart", rho)
plot_comp3 <- partview3(data, "sampPart", rho)

ratio <- 1 #6 / 9
width <- 8   # largeur en pouces
height <- width / ratio

pdf("partview_resilience_plotsT.pdf", width = width, height = height)
grid.arrange(plot_comp1, plot_comp2, plot_comp3, ncol = 1)

dev.off()