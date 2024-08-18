# Load necessary libraries
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
point_size <- 0.5

partview <- function(data, component) { 
    ggplot(data %>% filter(Component == component), aes(x = Time, y = Value, color = Source)) +
        geom_line(size = line_size) + # Lines
        geom_point(data = data %>% filter(Component == component & Time %% 10 == 0), size = 2) + # Points at intervals
        labs(#title = component,#paste("Brahms, Aupe and AupeMerge on",component, sep=" "),
            x = "Time steps",
            y = "Prop. of Byz. Samp.") +
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
            legend.box.background = element_rect(color = "gray"),
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

partview3 <- function(data, component) { 
    ggplot(data %>% filter(Component == component), aes(x = Time, y = Value, color = Source)) +
        geom_line(size = line_size) + # Lines
        geom_point(data = data %>% filter(Component == component & Time %% 10 == 0), size = 2) + # Points at intervals
        labs(#title = component,#paste("Brahms, Aupe and AupeMerge on",component, sep=" "),
            x = "Time steps",
            y = "Prop. of Byz. Samp.") +
        coord_cartesian(ylim = c(0, 1))+
        scale_y_continuous(breaks = seq(0.0, 1.0, by=0.2)) + 
        scale_color_manual(values = custom_colors) +
        theme(
            panel.grid.major = element_blank(),  # Remove major gridlines
            panel.grid.minor = element_blank(),  # Remove minor gridlines
            panel.background = element_rect("white"),
            panel.border = element_rect(colour = "black", linewidth=1,
            fill = NA),  
            legend.title = element_blank(),
            legend.position = c(0.575, 0.15),
            legend.spacing.y = unit(0.001, "cm"),
            text = element_text(size = 12, color="black"),
            axis.title.x = element_text(size = 12, face = "bold"),  
            axis.title.y = element_text(size = 12, face = "bold"),  
            axis.text.x = element_text(size = 12),  
            axis.text.y = element_text(size = 12), 
            plot.title = element_text(size = 12, face = "bold"),  
            legend.text = element_text(size = 12), 
                legend.key.width= unit(0.5, 'cm'),
            legend.background = element_rect(fill = "transparent"),
            axis.ticks = element_line(color = "black", linewidth=1), 
        )+
        guides(color=guide_legend(nrow=1))
}

partview_plot <- function(df1, df2, df3, df11, df22, df33, f) {  
    # Example data frames (replace these with your actual data frames)
    df1 <- data.frame(Time = seq_along(df1$comp1), pushPart = df1$comp1/100, pullPart = df1$comp2/100, sampPart = df1$comp3/100)
    df2 <- data.frame(Time = seq_along(df2$comp1), pushPart = df2$comp1/100, pullPart = df2$comp2/100, sampPart = df2$comp3/100)
    df3 <- data.frame(Time = seq_along(df3$comp1), pushPart = df3$comp1/100, pullPart = df3$comp2/100, sampPart = df3$comp3/100)

    df11 <- data.frame(Time = seq_along(df11$comp1), pushPart = df11$comp1/100, pullPart = df11$comp2/100, sampPart = df11$comp3/100)
    df22 <- data.frame(Time = seq_along(df22$comp1), pushPart = df22$comp1/100, pullPart = df22$comp2/100, sampPart = df22$comp3/100)
    df33 <- data.frame(Time = seq_along(df33$comp1), pushPart = df33$comp1/100, pullPart = df33$comp2/100, sampPart = df33$comp3/100)

    # Add an identifier column to each data frame
    df1 <- df1 %>% mutate(Source = "Brahms")
    df2 <- df2 %>% mutate(Source = "Aupe(t=0%)")
    #df3 <- df3 %>% mutate(Source = "Aupe(t=20%)")
    #df11 <- df11 %>% mutate(Source = "Aupe(t=5%)")
    df22 <- df22 %>% mutate(Source = "Aupe(t=10%)")
    df33 <- df33 %>% mutate(Source = "Aupe(t=30%)")
    # Reshape each data frame to long format
    df1_long <- df1 %>% pivot_longer(cols = ends_with("Part"), names_to = "Component", values_to = "Value")
    df2_long <- df2 %>% pivot_longer(cols = ends_with("Part"), names_to = "Component", values_to = "Value")
    #df3_long <- df3 %>% pivot_longer(cols = ends_with("Part"), names_to = "Component", values_to = "Value")

    #df11_long <- df11 %>% pivot_longer(cols = ends_with("Part"), names_to = "Component", values_to = "Value")
    df22_long <- df22 %>% pivot_longer(cols = ends_with("Part"), names_to = "Component", values_to = "Value")
    df33_long <- df33 %>% pivot_longer(cols = ends_with("Part"), names_to = "Component", values_to = "Value")
    # Combine the long format data frames
    
    combined_df <- bind_rows(df1_long, df2_long, #df3_long, df11_long,
    df22_long, df33_long)
    print(unique(combined_df$Source))

    levels=c("Aupe(t=0%)", "Aupe(t=1%)", "Aupe(t=5%)", "Aupe(t=10%)",
    "Aupe(t=20%)", "Aupe(t=30%)", "Aupe(t=100%)", "Brahms")
    combined_df$Source <- factor(combined_df$Source, levels = levels)
    # Create individual plots
    plot_comp1 <- partview(combined_df, "pushPart") 
    plot_comp2 <- partview(combined_df, "pullPart") 
    plot_comp3 <- partview3(combined_df, "sampPart")

    # Arrange the plots in a grid
    grid.arrange(plot_comp1, plot_comp2, plot_comp3, ncol = 1)
}
