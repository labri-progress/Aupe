

y_columns <- c("resilience")

x_top <- 0.5
y_top <- 0.8

y_axis_settings <- list(
  resilience = list(title = "Prop. of Byz. samples", 
    limits = c(0, 1), steps = c(0.0, 0.2, 0.4, 0.6, 0.8, 1.0), pos = c(x_top, y_top))
)

#ratio <- 0.8 
#width <- 5   # largeur en pouces

ratio <- 4 
width <- 10
height <- width / ratio

line_size <- 0.5
point_size <- 1.5
numb_col <- 3

#grid settings
xgrid <- 1
ygrid <- 3

#theme
mytheme <- theme(
      panel.grid.major = element_blank(), 
      panel.grid.minor = element_blank(), 
      panel.background = element_rect("white"),
      panel.border = element_rect(colour = "black", linewidth=1,
       fill = NA),  
      legend.spacing.y = unit(0.005, "cm"),
      text = element_text(size = 12, color="black"),
      axis.title.x = element_text(size = 14, face = "bold"),  
      axis.title.y = element_text(size = 12, face = "bold"),  
      axis.text.x = element_text(size = 12, face = "bold"),   
      axis.text.y = element_text(size = 12, face = "bold"),   
      plot.title = element_text(size = 14, face = "bold"), 
      legend.text = element_text(size = 10, face = "bold"), 
      legend.title = element_blank(), 
      legend.background = element_rect(fill = "transparent", colour = NA),
      legend.box.background = element_rect(fill = "transparent", colour = NA),
      axis.ticks = element_line(color = "black", linewidth=1), 
    )