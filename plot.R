#!/usr/bin/env Rscript
args = commandArgs(trailingOnly=TRUE)

library(ggplot2)

# Read the data from the file
# Rscript plot.R 1000 20
N=as.numeric(args[1])
f=as.numeric(args[2])
other="aupe-merge"
filename="rho1text26-30RPLY" # paste("text",f, sep="")
data <- read.table(filename, header = TRUE)

if (N==1000 ){
    VIEW_SIZE= 100
}else{
    VIEW_SIZE=160
}
# Ensure the data is read correctly
str(data)
data$avgByzN=(data$avgByzN/VIEW_SIZE)*100
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

