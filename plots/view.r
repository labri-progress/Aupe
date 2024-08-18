# Load necessary libraries
library(ggplot2)
library(dplyr)
library(tidyr)
library(gridExtra)



line_size <- 1
point_size <- 1.5

view_plot <- function(df1, df2, f, v) {
    print("viewplot")
    print(dim(df1))
    print(colnames(df1))
    df1 <- data.frame(Time = seq_along(df1$avgByzN), resilience = df1$avgByzN/v)
    rep = rep(f/100, length(df2$avgByzN))
    df0 <- data.frame(Time = seq_along(df2$avgByzN), resilience = rep)
    df2 <- data.frame(Time = seq_along(df2$avgByzN), resilience = df2$avgByzN/v)
    #
    # Add an identifier column to each data frame
    df1 <- df1 %>% mutate(Source = "Brahms")
    df2 <- df2 %>% mutate(Source = "Aupe-simple")
    df0 <- df0 %>% mutate(Source = "Optimal")
    print(dim(df1))
    # Combine the long format data frames
    df <- bind_rows(df1, df2, df0)
    #print(df)
    print(colnames(df))
    text_size = 14

custom_colors <- c("Basalt" = "#2CA02C", "Brahms" = "#FF7F00",
"Aupe-simple" = "#C77CFF", "Aupe(t=100%)" = "#00BFC4", "Aupe(t=1%)"="#FFFF00", 
"Aupe(t=5%)"="#FF3399", "Aupe(t=10%)"="#996600", 
"Aupe(t=20%)"="darkgreen", "Aupe(t=30%)"="black", 'Optimal'='black',
"Aupe-oracle" = "#FF0033")


custom_linetypes <- c('Basalt' = 'solid', 'Brahms' = 'solid',
'Aupe-simple' = 'solid', 'Aupe(t=30%)' = 'solid', 
'Aupe(t=5%)' = 'solid', 'Aupe(t=10%)' = 'solid',
    'Aupe(t=20%)' = 'solid', 'Aupe-oracle' = 'solid',
'Optimal'='dashed')

custom_shapes <- c('Basalt' = 16, 'Brahms' = 16, 
'Aupe(t=30%)' = 16, 'Aupe(t=5%)' = 16, 'Aupe(t=10%)' = 16,
    'Aupe(t=20%)' = 16, 'Aupe-oracle' = 16,
'Aupe-simple' = 16,'Optimal'=NA)

    levels=c("Aupe-simple", "Brahms", "Optimal")
    df$Source <- factor(df$Source, levels = levels)
    
    ggplot(df, aes(x = Time, y = resilience, color = Source,  linetype = Source, shape=Source)) +
        geom_line(size = 1) + # Lines
        geom_point(data = df %>% filter(Time %% 10 == 0), size = 2) + # Points at intervals
        labs(#title = "Brahms, Aupe and AupeMerge system resilience",
            x = "Time steps",
            y = "Prop. of Byz. Samp.") +
        theme_minimal() +
        coord_cartesian(ylim = c(0, 1))+
        scale_y_continuous(breaks = seq(0.0, 1.0, by=0.2)) + 
        scale_color_manual(values = custom_colors) +
    scale_linetype_manual(values = custom_linetypes) +
    scale_shape_manual(values = custom_shapes) +
        theme(
            panel.grid.major = element_blank(),  # Remove major gridlines
            panel.grid.minor = element_blank(),  # Remove minor gridlines
            panel.background = element_rect("white"),
            panel.border = element_rect(colour = "black", linewidth=1,
            fill = NA),  
            legend.title = element_blank(),
            legend.position = c(0.5, 0.15),
            legend.spacing.y = unit(0.005, "cm"),
            text = element_text(size = 12, color="black"),
            axis.title.x = element_text(size = text_size, face = "bold"),  
            axis.title.y = element_text(size = text_size, face = "bold"),  
            axis.text.x = element_text(size = text_size),  
            axis.text.y = element_text(size = text_size), 
            plot.title = element_text(size = text_size, face = "bold"),  
            legend.text = element_text(size = 16), 
                legend.key.width= unit(1, 'cm'),
            axis.ticks = element_line(color = "black", linewidth=1), 
        )+
        guides(shape = guide_legend(override.aes = list(size = 3)))+
        guides(color=guide_legend(ncol=3))

}