#!/usr/bin/env Rscript
args = commandArgs(trailingOnly=TRUE)

library(ggplot2)
library(dplyr)


# Read the data from the file
# Rscript plot.R 1000 20
N=as.numeric(args[1])
f=as.numeric(args[2])
other="aupe"
filename="kvs-10-3000" #"bm-10-1000-5" #"rho1text26-30RPLY" # paste("text",f, sep="")
data <- read.table(filename, header = TRUE)

if (N==1000 ){
    VIEW_SIZE= 100
}else{
    VIEW_SIZE=160
}
# Ensure the data is read correctly
data <- data %>% filter(time > 2, time <= 200)
data$avgByzN=(data$avgByzN/VIEW_SIZE)
data$streamN=data$pByzRecv #(data$avgByzRecv/data$avgRecv)
# filter NANs
data <- data[!is.na(data$avgByzN) & !is.na(data$streamN), ]
data$biasfactor=data$avgByzRecv/(data$avgRecv-data$avgByzRecv)

str(data)

source("theme.r")
library(tidyr)


data_long <- data %>%
  pivot_longer(cols = c(avgByzN, streamN, biasfactor), 
               names_to = "metric", values_to = "value")

data_long$metric <- recode(data_long$metric,
                         "avgByzN" = "Prop. of Byz. samples",
                         "streamN" = "Prop. of Byz. received",
                         "biasfactor" = "Bias factor")

pdf(paste(filename, ".pdf", sep=""))
ggplot(data_long, aes(x = time, y = value, color = metric)) +
  geom_line() +
  geom_hline(yintercept = f/100, linetype = "dashed", color = "gray80")+
  facet_wrap(~ metric, scales = "free_y", ncol = 1) +
  labs(x = "Round steps", y = "Value") +
  mytheme +
  theme(legend.position = "none") +
  scale_y_continuous(
    breaks = function(lims) {
      if (lims[2] <= 1) seq(0, 1, 0.2) else pretty(lims)
    },
    limits = function(lims) {
      if (lims[2] <= 1) c(0, 1) else lims
    }
  )

dev.off()
quit()
data_long <- data %>%
  pivot_longer(cols = c(avgByzN, streamN, biasfactor), 
               names_to = "type", 
               values_to = "value")
#data_long
ggplot(data_long, aes(x = time, y = value, color = type)) +
  geom_line() +
  labs(x = "Round steps",
       y = "Prop. of Byz. samples") +
  coord_cartesian(ylim = c(0.0, 2.2)) +
  scale_y_continuous(breaks = seq(0, 2.2, 0.2)) +
  mytheme +
  theme(
      legend.position = c(0.8,0.8))

quit()

res=tail(data$avgByzN, 1)
print(res)
# Plot the evolution of avgByzN over time
title=paste(other," Byzantine proportion inside views over Time N=", N," v=", VIEW_SIZE,
  " f=", f, "%", sep="")
ggplot(data, aes(x = time, y = avgByzN)) +
  geom_line(color = "blue") +
  labs(title = title,
       x = "Time",
       y = "avgByzN") +
       coord_cartesian( ylim = c(0, 100)) +
  scale_y_continuous(breaks = seq(0, 100, 10))+
  #geom_hline(yintercept = res, linetype="dotted", color="red")+
  geom_hline(yintercept = f, linetype="dotted", color="red")+
  theme(
    panel.grid.major = element_line(size = 0.5),  # Réduire la taille des lignes de la grille principale
    panel.grid.minor = element_line(size = 0.25), # Réduire la taille des lignes de la grille secondaire
    panel.grid.major.x = element_line(size = 0.5), # Réduire la taille des lignes de la grille principale sur l'axe x
    panel.grid.minor.x = element_line(size = 0.25),# Réduire la taille des lignes de la grille secondaire sur l'axe x
    panel.grid.major.y = element_line(size = 0.5), # Réduire la taille des lignes de la grille principale sur l'axe y
    panel.grid.minor.y = element_line(size = 0.25) # Réduire la taille des lignes de la grille secondaire sur l'axe y
  ) 

  data$avgByzSamp=(data$avgByzSamp/VIEW_SIZE)*100
  res=tail(data$avgByzSamp, 1)
  print(res)
  ggplot(data, aes(x = time, y = avgByzSamp)) +
  geom_line(color = "blue") +
  labs(title = "Byzantine proportion inside sample over Time",
       x = "Time",
       y = "avgByzSamp") +
       coord_cartesian( ylim = c(0, 100)) +
  scale_y_continuous(breaks = seq(0, 100, 10))+
  #geom_hline(yintercept = res, linetype="dotted", color="red")
  geom_hline(yintercept = f, linetype="dotted", color="red")

#theme_minimal()

