CIN     = "compoIN.txt"
COUT    = "compoOUT.txt"
CVIEW   = "compoVIEW.txt"
COV     = "coverage.txt"
INDEG   = "indegree.txt"
OUTDEG  = "outdegree.txt"


library(ggplot2)

custom_colors <- c("Basalt" = "#2CA02C", "Brahms" = "#FF7F00",
"Aupe(t=0%)" = "#C77CFF", "Aupe(t=100%)" = "#00BFC4", "Aupe(t=1%)"="#FFFF00", 
"Aupe(t=5%)"="#FF3399", "Aupe(t=10%)"="#996600", 
"Aupe(t=20%)"="darkgreen", "Aupe(t=30%)"="black", 
"AupeGlobal" = "#FF0033")

line_size <- 1
point_size <- 1.5
ratio <- 16 / 9
width <- 8   # largeur en pouces
height <- width / ratio   # hauteur calculée en fonction du ratio
# Charger ggplot2
library(ggplot2)

# Définir un thème ggplot2 personnalisé
custom_theme <- function() {
  theme(
    panel.grid.major = element_blank(), 
            panel.grid.minor = element_blank(), # Remove major gridlines
            panel.background = element_rect("white"),
            panel.border = element_rect(colour = "black", linewidth=1,
            fill = NA),  
            legend.title = element_blank(),
            legend.position = c(0.35, 0.15),
            legend.spacing.y = unit(0.001, "cm"),
            text = element_text(size = 12, color="black"),
            axis.title.x = element_text(size = 12, face = "bold"),  
            axis.title.y = element_text(size = 12, face = "bold"),  
            axis.text.x = element_text(size = 12),  
            axis.text.y = element_text(size = 12), 
            plot.title = element_text(size = 12, face = "bold"),  
            legend.text = element_text(size = 10), 
             legend.key = element_blank(),
            
             legend.key = element_blank(),
             legend.background = element_blank(), 
            axis.ticks = element_line(color = "black", linewidth=1),
        )+
        guides(color=guide_legend(nrow=2))
}

custom_theme2 <- function() {
  theme(
    panel.grid.major = element_blank(), 
            panel.grid.minor = element_blank(), # Remove major gridlines
            panel.background = element_rect("white"),
            panel.border = element_rect(colour = "black", linewidth=1,
            fill = NA),  
            legend.title = element_blank(),
            legend.position = c(0.35, 0.15),
            legend.spacing.y = unit(0.001, "cm"),
            text = element_text(size = 12, color="black"),
            axis.title.x = element_text(size = 12, face = "bold"),  
            axis.title.y = element_text(size = 12, face = "bold"),  
            axis.text.x = element_text(size = 12),  
            axis.text.y = element_text(size = 12), 
            plot.title = element_text(size = 12, face = "bold"),  
            legend.text = element_text(size = 10), 
             legend.key = element_blank(),
            
             legend.key = element_blank(),
             legend.background = element_blank(), 
            axis.ticks = element_line(color = "black", linewidth=1),
        )+
        guides(color=guide_legend(nrow=2))
}