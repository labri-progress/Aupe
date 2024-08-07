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
point_size <- 1.5

partview <- function(data, component) { 
    ggplot(data %>% filter(Component == component), aes(x = Time, y = Value, color = Source, linetype = Source)) +
        geom_line(size = line_size) + # Lines
        geom_point(data = data %>% filter(Component == component & Time %% 10 == 0), size = 2) + # Points at intervals
        labs(title = component,#paste("Brahms, Aupe and AupeMerge on",component, sep=" "),
            x = "Time steps",
            y = "Prop. of Byz. Samples") +
        theme_minimal() +
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
        )#+
        #guides(shape = guide_legend(override.aes = list(size = 3)))+
        #guides(color=guide_legend(ncol=3))

}

partview_plot <- function(df1, df2, df3, f) {  
    # Example data frames (replace these with your actual data frames)
    df1 <- data.frame(Time = seq_along(df1$comp1), pushPart = df1$comp1/100, pullPart = df1$comp2/100, sampPart = df1$comp3/100)
    df2 <- data.frame(Time = seq_along(df2$comp1), pushPart = df2$comp1/100, pullPart = df2$comp2/100, sampPart = df2$comp3/100)
    df3 <- data.frame(Time = seq_along(df3$comp1), pushPart = df3$comp1/100, pullPart = df3$comp2/100, sampPart = df3$comp3/100)


    # Add an identifier column to each data frame
    df1 <- df1 %>% mutate(Source = "Brahms")
    df2 <- df2 %>% mutate(Source = "Aupe")
    df3 <- df3 %>% mutate(Source = "AupeMerge")

    # Reshape each data frame to long format
    df1_long <- df1 %>% pivot_longer(cols = ends_with("Part"), names_to = "Component", values_to = "Value")
    df2_long <- df2 %>% pivot_longer(cols = ends_with("Part"), names_to = "Component", values_to = "Value")
    df3_long <- df3 %>% pivot_longer(cols = ends_with("Part"), names_to = "Component", values_to = "Value")

    # Combine the long format data frames
    combined_df <- bind_rows(df1_long, df2_long, df3_long)
    # Create individual plots
    plot_comp1 <- partview(combined_df, "pushPart")
    plot_comp2 <- partview(combined_df, "pullPart")
    plot_comp3 <- partview(combined_df, "sampPart")

    # Arrange the plots in a grid
    grid.arrange(plot_comp1, plot_comp2, plot_comp3, ncol = 1)
}

view_plot <- function(df1, df2, df3, f, v) {
    print("viewplot")
    print(dim(df1))
    print(colnames(df1))
    df1 <- data.frame(Time = seq_along(df1$avgByzN), resilience = df1$avgByzN/v)
    df2 <- data.frame(Time = seq_along(df2$avgByzN), resilience = df2$avgByzN/v)
    df3 <- data.frame(Time = seq_along(df3$avgByzN), resilience = df3$avgByzN/v)
    # Add an identifier column to each data frame
    df1 <- df1 %>% mutate(Source = "Brahms")
    df2 <- df2 %>% mutate(Source = "Aupe(t=0%)")
    df3 <- df3 %>% mutate(Source = "Aupe(t=100%)")
    print(dim(df1))
    # Combine the long format data frames
    df <- bind_rows(df1, df2, df3)
    #print(df)
    print(colnames(df))

    ggplot(df, aes(x = Time, y = resilience, color = Source, linetype = Source)) +
        geom_line(size = 1) + # Lines
        geom_point(data = df %>% filter(Time %% 10 == 0), size = 2) + # Points at intervals
        labs(#title = "Brahms, Aupe and AupeMerge system resilience",
            x = "Time steps",
            y = "Prop. of Byz. Samples") +
        theme_minimal() +
        coord_cartesian(ylim = c(0, 1))+
        scale_y_continuous(breaks = seq(0.0, 1.0, by=0.2)) + 
        scale_color_manual(values = custom_colors) +theme(
            panel.grid.major = element_blank(),  # Remove major gridlines
            panel.grid.minor = element_blank(),  # Remove minor gridlines
            panel.background = element_rect("white"),
            panel.border = element_rect(colour = "black", linewidth=1,
            fill = NA),  
            legend.title = element_blank(),
            legend.position = c(0.6, 0.2),
            legend.box.background = element_rect(color = "gray"),
            legend.spacing.y = unit(0.005, "cm"),
            text = element_text(size = 12, color="black"),
            axis.title.x = element_text(size = 14, face = "bold"),  
            axis.title.y = element_text(size = 14, face = "bold"),  
            axis.text.x = element_text(size = 14),  
            axis.text.y = element_text(size = 14), 
            plot.title = element_text(size = 14, face = "bold"),  
            legend.text = element_text(size = 16),  
            #legend.title = element_text(size = 14),  # Increase legend title size
            #legend.key.height= unit(0.4, 'cm'),
                legend.key.width= unit(1, 'cm'),
            axis.ticks = element_line(color = "black", linewidth=1), 
        )+
        guides(shape = guide_legend(override.aes = list(size = 3)))+
        guides(color=guide_legend(ncol=3))

}