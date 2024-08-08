#!/usr/bin/env Rscript
args = commandArgs(trailingOnly=TRUE)

library(dplyr)

# 0. Loading
filename2="../dsncompoVIEW"
filename1="../dsncompoVIEW.txt"
df1 <- read.table(filename1, header = TRUE, sep = "", stringsAsFactors = FALSE)

df2 <- read.table(filename2, header = TRUE, sep = "", stringsAsFactors = FALSE)
k=as.integer(args[1])
rho_value=paste("rho", k, sep="")
print(rho_value)
df1 <- df1 %>% filter(rho == rho_value)
df2 <- df2 %>% filter(rho == rho_value)

df1$Strat <- paste("Aupe(t=",df1$trusty,"%)", sep = "")

unique(df1)
unique(df2)
merged_df <- inner_join(df1, df2, by = "faulty", 
    suffix = c("_df1", "_df2"),
    relationship = "many-to-many")

# Filtrer pour obtenir les lignes où la résilience de df1 dépasse celle de df2
result <- merged_df %>%
  mutate(difference = resilience_df2 - resilience_df1) %>%  # Calculer la différence de résilience
  #filter(difference > 0) %>%  # Filtrer les lignes où la différence est positive
  select(faulty, Strat_df1, difference)

print(unique(result))

print(min(result$difference))
print(max(result$difference))

library(ggplot2)
custom_colors <- c("Basalt" = "#2CA02C", "Brahms" = "#FF7F00",
"Aupe(t=0%)" = "#C77CFF", "Aupe(t=100%)" = "#00BFC4", "Aupe(t=1%)"="#FFFF00", 
"Aupe(t=5%)"="#FF3399", "Aupe(t=10%)"="#996600", 
"Aupe(t=20%)"="darkgreen", "Aupe(t=30%)"="black", 
"AupeGlobal" = "#FF0033")

ratio <- 1
width <- 8 
height <- width / ratio
pdf(paste("comparisonWithBasaltrho=", rho_value, sep=""), width = width, height = height)

kept <- c("Aupe(t=0%)", "Aupe(t=0%)", "Aupe(t=5%)", "Aupe(t=10%)",
    "Aupe(t=20%)", "Aupe(t=30%)", "Aupe(t=100%)", "AupeGlobal")

result <- result[(result$Strat_df1 %in% kept), ]
print(unique(result$Strat_df1))
line_size <- 1
point_size <- 1.5
y_breaks <- seq(-40, 40, 5) #append(c(0.0), seq(max(-40, min(result$difference)), min(40, max(result$difference)), by=5))
y_breaks
ggplot(result, aes(x = faulty, 
    y = difference, color = Strat_df1)) + #, linetype = Strat_df1)) +
        geom_point(size=point_size) +
        geom_line(linewidth=line_size) +
        geom_abline(intercept = 0, slope = 0, linetype = "dashed", color = "black") + 
        labs(#title = paste("Resilience in ", component, sep=""),
          x = "Prop. of Byz. nodes", 
          y = "Difference with Basalt") +
            theme_minimal() +
            scale_y_continuous(breaks = ) +
            scale_color_manual(values = custom_colors) +
            theme(legend.position = c(0.7, 0.15),
                legend.title = element_blank(),
                #panel.grid.major = element_blank(),  # Remove major gridlines
                #panel.grid.minor = element_blank(),  # Remove minor gridlines
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
dev.off()