# Load necessary libraries
library(ggplot2)
library(dplyr)
library(tidyr)

aesplot <- function(df1, df2, df3, f) {  
    # Example data frames (replace these with your actual data frames)
    df1 <- data.frame(Time = seq_along(df1$comp1), pushPart = df1$comp1/100, pullPart = df1$comp2/100, sampPart = df1$comp3/100)
    df2 <- data.frame(Time = seq_along(df2$comp1), pushPart = df2$comp1/100, pullPart = df2$comp2/100, sampPart = df2$comp3/100)
    df3 <- data.frame(Time = seq_along(df3$comp1), pushPart = df3$comp1/100, pullPart = df3$comp2/100, sampPart = df3$comp3/100)


    # Add an identifier column to each data frame
    df1 <- df1 %>% mutate(Source = "brahms")
    df2 <- df2 %>% mutate(Source = "aupe")
    df3 <- df3 %>% mutate(Source = "aupeMerge")

    # Reshape each data frame to long format
    df1_long <- df1 %>% pivot_longer(cols = ends_with("Part"), names_to = "Component", values_to = "Value")
    df2_long <- df2 %>% pivot_longer(cols = ends_with("Part"), names_to = "Component", values_to = "Value")
    df3_long <- df3 %>% pivot_longer(cols = ends_with("Part"), names_to = "Component", values_to = "Value")

    # Combine the long format data frames
    combined_df <- bind_rows(df1_long, df2_long, df3_long)
    #print(unique(combined_df$Component))
    # Create an interaction column for color and linetype
    combined_df <- combined_df %>% mutate(Interaction = interaction(Source, Component)) 
    
    combined_df <- combined_df %>%
    mutate(Interaction = factor(Interaction, levels = c("brahms.pushPart", "brahms.pullPart", "brahms.sampPart",
                                    "aupe.pushPart", "aupe.pullPart", "aupe.sampPart",
                                    "aupeMerge.pushPart", "aupeMerge.pullPart", "aupeMerge.sampPart")))

    override.color=  c("chocolate1", "darkgreen", "deepskyblue", "chocolate1", "darkgreen", 
        "deepskyblue", "chocolate1", "darkgreen", "deepskyblue") #c(2, 4, 3, 2, 4, 3, 2, 4, 3)
    
    override.shape <- c(16, 17, 15, 16, 17, 15, 16, 17, 15)
    override.linetype <- c(1, 3, 5, 1, 3, 5, 1, 3, 5)

    override.shape = override.shape[order(override.shape)]
    override.linetype = override.linetype[order(override.linetype)]
    # Create the plot
    p <- ggplot(combined_df, aes(x = Time, y = Value, color = Interaction, linetype = Interaction, shape = Interaction)) +
    geom_line(linewidth = 0.75) + # Lines
    geom_point(data = combined_df %>% filter(Time %% 20 == 0), size = 2) + # Points at intervals
    labs(title = paste("Brahms, Aupe and AupeMerge on the view parts for f=", f, "%", sep=" "),
        x = "Time steps", 
        y = "Proportion of Byzantine Samples") +
    theme_minimal() +
    #scale_color_manual(values = custom_colors) +
    scale_color_manual(values=override.color) +
    scale_linetype_manual(values=override.linetype) +
    #coord_cartesian( ylim = c(0.5, 1.0))+ # Zooming in with coord_cartesian
    #scale_linetype_manual(values = custom_lines) +
    #scale_x_continuous(breaks = c(0.0, 0.1, 0.2, 0.3, 0.4, 0.5)) +
    scale_shape_manual(values=override.shape) +
    scale_y_continuous(breaks = c(0.0, 0.2, 0.4, 0.6, 0.8, 1.0)) +
    theme(
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
      axis.title.x = element_text(size = 14, face = "bold"),  # Increase x-axis title size
      axis.title.y = element_text(size = 14, face = "bold"),  # Increase y-axis title size
      axis.text.x = element_text(size = 14),  # Increase x-axis text size
      axis.text.y = element_text(size = 14),  # Increase y-axis text size
      plot.title = element_text(size = 14, face = "bold"),  # Increase plot title size
      legend.text = element_text(size = 16),  # Increase legend text size
      #legend.title = element_text(size = 14),  # Increase legend title size
      #legend.key.height= unit(0.4, 'cm'),
        legend.key.width= unit(1, 'cm'),
      axis.ticks = element_line(color = "black", linewidth=1), 
    )+
    guides(shape = guide_legend(override.aes = list(size = 3)))+
    guides(color=guide_legend(ncol=2))

    return(p)
}