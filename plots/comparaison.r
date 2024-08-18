CIN     = "compoIN.txt"
COUT    = "compoOUT.txt"
CVIEW   = "compoVIEW.txt"
COV     = "coverage.txt"
INDEG   = "indegree.txt"
OUTDEG  = "outdegree.txt"

source("compute.r")
# Load necessary libraries
library(ggplot2)
library(dplyr)
library(tidyr)
library(gridExtra)

custom_colors <- c("Basalt" = "#2CA02C", "Brahms" = "#FF7F00",
"Aupe(t=0%)" = "#C77CFF", "Aupe(t=100%)" = "#00BFC4", "Aupe(t=1%)"="#FFFF00", 
"Aupe(t=5%)"="#FF3399", "Aupe(t=10%)"="#996600", 
"Aupe(t=20%)"="#006600", "Aupe(t=30%)"="#000000", 
"AupeGlobal(t=100%)" = "#FF0033", "AupeGlobal(t=1%)"="#33FF99", 
"AupeGlobal(t=5%)"="#FF3399", "AupeGlobal(t=10%)"="#3399FF", 
"AupeGlobal(t=20%)"="#CC6666", "AupeGlobal(t=30%)"="#999000")


line_size <- 1
point_size <- 1.5
ratio <- 16 / 9
width <- 8   # largeur en pouces
height <- width / ratio   # hauteur calculée en fonction du ratio

#  width = width, height = height)

partview_plot <- function( df1, df2, df3, df4, df5, df6, df7, df8, df9, f, rho) {
    print("viewplot")
    print(dim(df1))
    print(colnames(df1))
    print(dim(df1))
    
    df1 <- data.frame(Time = seq_along(df1$avgByzN), comp = df1$comp/100)
    df2 <- data.frame(Time = seq_along(df2$avgByzN), comp = df2$comp/100)
    df3 <- data.frame(Time = seq_along(df3$avgByzN), comp = df3$comp/100)
    df4 <- data.frame(Time = seq_along(df4$avgByzN), comp = df4$comp/100)
    df5 <- data.frame(Time = seq_along(df5$avgByzN), comp = df5$comp/100)
    df6 <- data.frame(Time = seq_along(df6$avgByzN), comp = df6$comp/100)
    df7 <- data.frame(Time = seq_along(df7$avgByzN), comp = df7$comp/100)
    df8 <- data.frame(Time = seq_along(df8$avgByzN), comp = df8$comp/100)
    df9 <- data.frame(Time = seq_along(df9$avgByzN), comp = df9$comp/100)
    

    df1 <- df1 %>% mutate(Strat = "Aupe(t=1%)")
    df2 <- df2 %>% mutate(Strat = "Aupe(t=5%)")
    df3 <- df3 %>% mutate(Strat = "Aupe(t=10%)")
    df4 <- df4 %>% mutate(Strat = "Aupe(t=20%)")
    df5 <- df5 %>% mutate(Strat = "Aupe(t=30%)")
    df6 <- df6 %>% mutate(Strat = "Basalt")
    df7 <- df7 %>% mutate(Strat = "AupeGlobal(t=10%)")
    df8 <- df8 %>% mutate(Strat = "AupeGlobal(t=20%)")
    df9 <- df9 %>% mutate(Strat = "AupeGlobal(t=30%)")

    df <- bind_rows(df1, df2, df3, df4, df5, df6, df7, df8, df9)
    #print(df)
    print(colnames(df))
    
    levels=c("Aupe(t=0%)", "Aupe(t=1%)", "Aupe(t=5%)", "Aupe(t=10%)", "AupeGlobal(t=10%)",
    "Aupe(t=20%)", "AupeGlobal(t=20%)", "Aupe(t=30%)", "AupeGlobal(t=30%)",
    "Aupe(t=100%)", "Basalt")
    df$Strat <- factor(df$Strat, levels = levels)

    pos1=c(0.3, 0.2)
    pos0=c(0.7, 0.7)
    ggplot(df, aes(x = Time, y = comp, color = Strat)) + #, linetype = trusted)) +
        geom_line(size = line_size) + # Lines
        geom_point(data = df %>% filter(Time %% 10 == 0), size = point_size) + 
        geom_hline(yintercept = f, color = "black", linetype = "dashed", size = 1) +
        labs(title = paste("Aupe vs Basalt f=", f, "% rho=", rho, sep=""),
            x = "Time steps",
            y = "Prop. of Byz. Samples") +
        theme_minimal() +
        coord_cartesian(ylim = c(0, 1))+
        scale_y_continuous(breaks = seq(0.0, 1.0, by=0.1)) + #c(0.0, 0.2, 0.4, 0.6, 0.8, 1.0)) +
        scale_color_manual(values = custom_colors) +
        theme(
            panel.grid.major = element_blank(), 
            panel.grid.minor = element_blank(), # Remove major gridlines
            panel.background = element_rect("white"),
            panel.border = element_rect(colour = "black", linewidth=1,
            fill = NA),  
            legend.title = element_blank(),
            legend.position = c(0.45, 0.1),
            legend.spacing.y = unit(0.001, "cm"),
            text = element_text(size = 12, color="black"),
            axis.title.x = element_text(size = 12, face = "bold"),  
            axis.title.y = element_text(size = 12, face = "bold"),  
            axis.text.x = element_text(size = 12),  
            axis.text.y = element_text(size = 12), 
            legend.text = element_text(size = 10), 
             legend.key = element_blank(),
             legend.background = element_blank(), 
            axis.ticks = element_line(color = "black", linewidth=1),
        )+
        guides(color=guide_legend(nrow=2))

}
write_resultsT <- function(filename, expe, f, strat, rho,
    resilience, sm, ttC, roundNumber, comment, name) {
    file.info(filename)$size
    if (!file.exists(filename)) {
       head <- "Expe     faulty     Strat     rho     resilience     ttC     sm     round     comment"
        if(name == COV){
            head <- "Expe faulty SMemory Strat coverage round comment"
        }
        write(head, append=TRUE, file = filename)
    }
    separator = "        "
    sol = paste(expe, f*100, strat, rho, resilience, ttC, sm, roundNumber, comment, sep = separator)
    write(sol, append=TRUE, file = filename)
}

comp <- function(args, path, topic) {  
    # 0. Data      
    #print(path)
    N = as.numeric(args[1])
    v = as.numeric(args[2])
    f = as.numeric(args[3])
    t = as.numeric(args[4])
    sm = as.numeric(args[5])
    expe = as.numeric(args[6])
    strat = args[7]
    merge = args[8]
    gamma = as.double(args[9])
    roundMAX = as.numeric(args[10])
    folder = args[11]
    k=as.numeric(args[12])
    r=as.numeric(args[13])

    # 1. Plots
    
    ymax = 100

    rho=paste("rho",k/r, sep="")
    print(rho)
    filepath = paste("/home/amukam/thss/simulation/Aupe/analysis/",rho, "/", 
        N, sep="")

    t1=1
    t2=5
    t3=10
    t4=20
    t5=30
    path1 = paste(filepath,"/", strat,"/text",f*100,"-", t1, sep="")
    path2 = paste(filepath,"/", strat,"/text",f*100,"-", t2, sep="")
    path3 = paste(filepath,"/", strat,"/text",f*100,"-", t3, sep="")
    path4 = paste(filepath,"/", strat,"/text",f*100,"-", t4, sep="")
    path5 = paste(filepath,"/", strat,"/text",f*100,"-", t5, sep="")
    path6 = paste(filepath,"/basalt/text",f*100, sep="")
    strat2="aupe-global"
    path33 = paste(filepath,"/", strat2,"/text",f*100,"-10", sep="")
    path44 = paste(filepath,"/", strat2,"/text",f*100,"-20", sep="")
    path55 = paste(filepath,"/", strat2,"/text",f*100,"-30", sep="")

    print(path1)
    print(path2)
    print(path5)
    print(path6)
    print(path55)

    merge1 <- read.table(path1, header = TRUE)
    roundNumber1 <- nrow(merge1)
    merge2 <- read.table(path2, header = TRUE)
    roundNumber2 <- nrow(merge2)
    merge3 <- read.table(path3, header = TRUE)
    roundNumber3 <- nrow(merge3)
    merge4 <- read.table(path4, header = TRUE)
    roundNumber4 <- nrow(merge4)
    merge5 <- read.table(path5, header = TRUE)
    roundNumber5 <- nrow(merge5)
    merge6 <- read.table(path6, header = TRUE)
    roundNumber6 <- nrow(merge6)

    merge33 <- read.table(path33, header = TRUE)
    roundNumber33 <- nrow(merge33)
    merge44 <- read.table(path44, header = TRUE)
    roundNumber44 <- nrow(merge44)
    merge55 <- read.table(path55, header = TRUE)
    roundNumber55 <- nrow(merge55)

    print(paste("roundNumber1",roundNumber1, "vs roundNumber2", roundNumber2,
    "and roundNumber5", roundNumber5))
    comment="" # for logging
    missing = roundMAX +1 - roundNumber1 # round of initialisation
    if (missing != 0) {
        print(c(nrow(merge1), ncol(merge1)))
        print(paste("roundMAX", roundMAX, "roundNumber", roundNumber1, 
            "--> missing", missing, "rounds"))
        sentence = paste("missing", missing, "rounds", sep="") 
        if (comment==""){
            comment = sentence
        } else{
            comment = paste(comment, "and", sentence, sep ="")
        }
    }
    
    merge1$comp=(merge1$avgByzN/v)*100
    merge2$comp=(merge2$avgByzN/v)*100
    merge3$comp=(merge3$avgByzN/v)*100
    merge4$comp=(merge4$avgByzN/v)*100
    merge5$comp=(merge5$avgByzN/v)*100
    merge6$comp=(merge6$avgByzN/v)*100


    merge33$comp=(merge33$avgByzN/v)*100
    merge44$comp=(merge44$avgByzN/v)*100
    merge55$comp=(merge55$avgByzN/v)*100

    title="Aupe Merge studying"
    title=paste(title, #"\n Byzantine proportion inside parts of the view over Time \n", 
        "f=", f*100,"% N=", N, " v=s=", v, " F=10 \n rounds=", roundNumber1)
    
    resilience1=c(tail(merge1, 1)$comp)
    resilience2=c(tail(merge2, 1)$comp)
    resilience3=c(tail(merge3, 1)$comp)
    resilience4=c(tail(merge4, 1)$comp)
    resilience5=c(tail(merge5, 1)$comp)
    resilience6=c(tail(merge6, 1)$comp)

    resilience33=c(tail(merge33, 1)$comp)
    resilience44=c(tail(merge44, 1)$comp)
    resilience55=c(tail(merge55, 1)$comp)
    print(paste("resilience1",resilience1, "vs resilience2", resilience2, 
    "and resilience5", resilience5))
    
    #PLOTS
    print(partview_plot(merge1, merge2, merge3, merge4, merge5, merge6, merge33, merge44, merge55, f, k))
   
    ttc1 <- detect_first_convergence_index(merge1$comp, f, roundNumber1)
    ttc2 <- detect_first_convergence_index(merge2$comp, f, roundNumber2)
    ttc3 <- detect_first_convergence_index(merge3$comp, f, roundNumber3)
    ttc4 <- detect_first_convergence_index(merge4$comp, f, roundNumber4)
    ttc5 <- detect_first_convergence_index(merge5$comp, f, roundNumber5)
    ttc6 <- detect_first_convergence_index(merge6$comp, f, roundNumber6)
    
    ttc33 <- detect_first_convergence_index(merge33$comp, f, roundNumber33)
    ttc44 <- detect_first_convergence_index(merge44$comp, f, roundNumber44)
    ttc55 <- detect_first_convergence_index(merge55$comp, f, roundNumber55)
    # 2. Logs
    
    if (comment==""){
    comment="RAS"
    }
    system = paste("N=", N, " v=",  v, sep="")
    study = paste("strat=", strat, sep="")
    mainDir = "../results/"
    dir.create(file.path(mainDir, system)) # check folder existence
    new = paste(mainDir, system, sep="")
    dir.create(file.path(new, study))
    
    filename = paste(new, "/","dsn", path,  sep="")
    
    write_resultsT(filename, expe, f, paste("Aupe(t=",t1,"%)", sep = ""), rho, resilience1, sm,
        ttc1, roundNumber1, comment, path)
    write_resultsT(filename, expe, f, paste("Aupe(t=",t2,"%)", sep = ""), rho, resilience2, sm,
        ttc2, roundNumber2, comment, path)
    write_resultsT(filename, expe, f, paste("Aupe(t=",t3,"%)", sep = ""), rho, resilience3, sm,
        ttc3, roundNumber3, comment, path)
    write_resultsT(filename, expe, f, paste("Aupe(t=",t4,"%)", sep = ""), rho, resilience4, sm,
        ttc4, roundNumber4, comment, path)
    write_resultsT(filename, expe, f, paste("Aupe(t=",t5,"%)", sep = ""), rho, resilience5, sm,
        ttc5, roundNumber5, comment, path)
    write_resultsT(filename, expe, f, "Basalt", rho, resilience6, sm,
        ttc6, roundNumber6, comment, path)
    
    write_resultsT(filename, expe, f, paste("AupeGlobal(t=10%)", sep = ""), rho, resilience33, sm,
        ttc33, roundNumber33, comment, path)
    write_resultsT(filename, expe, f, paste("AupeGlobal(t=20%)", sep = ""), rho, resilience44, sm,
        ttc44, roundNumber44, comment, path)
    write_resultsT(filename, expe, f, paste("AupeGlobal(t=30%)", sep = ""), rho, resilience55, sm,
        ttc55, roundNumber55, comment, path)
}
