#!/usr/bin/env Rscript
#args = commandArgs(trailingOnly=TRUE)


write_results <- function(filename, expe, f, t, r, strat, budget,
    resilience, sm, roundNumber) {
    file.info(filename)$size
    if (!file.exists(filename)) {
       head <- "Expe     faulty     trusty     force     strat     budget     resilience     sm     round"
        write(head, append=TRUE, file = filename)
    }
    separator = "        "
    sol = paste(expe, f, t, r, strat, budget, resilience, sm, roundNumber, sep = separator)
    write(sol, append=TRUE, file = filename)
}
cms <- function(args, topic) {  
    # 0. Data     
    N = as.numeric(args[1])
    v = as.numeric(args[2])
    f = as.numeric(args[3])
    t = as.numeric(args[4])
    r = as.numeric(args[5])
    sm = as.numeric(args[6])
    stratname = args[7]
    budget=as.numeric(args[8])

    print(args)
    # 1. Plots
    
    name = "resilience" #sub(pattern = "(.*)\\..*$", replacement = "\\1", basename(path))
    #print(name)
    ymax = 100
    if (stratname=="kvs"){
        filepath = paste(Folder,"kvs-", r, "-", f, sep="")
    } else if (stratname=="bm"){
        filepath = paste(Folder,"bm-", r, "-", f, "-", budget, sep="")
    } else if (stratname=="Brahms"){
        filepath = paste(Folder,"br-", r, "-", f, sep="")
    } else if (stratname=="Basalt"){
        filepath = paste(Folder,"bs-", r, "-", f, sep="")
    } else {
        print("Error: unknown strategy")
        return
    }
    if (t!=0){
        filepath = paste(filepath,"-",t*100, sep="")
    }
    print(filepath)
    
    strat <- read.table(filepath, header = TRUE)
    roundNumber1 <- nrow(strat)
    
    print(paste("roundNumber1",roundNumber1))
    comment="" # for logging
    missing = roundMAX +1 - roundNumber1 # round of initialisation
    if (missing != 0) {
        print(c(nrow(strat), ncol(strat)))
        print(paste("roundMAX", roundMAX, "roundNumber", roundNumber1, 
            "--> missing", missing, "rounds"))
        sentence = paste("missing", missing, "rounds", sep="") 
        if (comment==""){
            comment = sentence
        } else{
            comment = paste(comment, "and", sentence, sep ="")
        }
    }
    strat$comp=(strat$avgByzN/v)*100
    title=paste("Byzantine proportion inside view over Time f=", 
        f/100,"%","  t=", t*100,"% Budget=", budget, " 
        N=", N, " v=s=", v, " r=", r, " rounds=", roundNumber1, sep="")
    
    
    rounds_to_check = c(200, 500, 1000, 1500, 2000)
    #rounds_to_check = c(200, 600, 1000, 1400, 1800, 2000)
    rounds = c()
    resiliences = c()
    for (round in rounds_to_check) {
        if (round <= roundNumber1) {
            rounds <- c(rounds, round)
            resiliences <- c(resiliences, strat$comp[round])
        }
    }
    resilience_at_round <- data.frame(rounds, resiliences)
    #resilience1=tail(strat, 1)$comp
    print(paste("resilience",resilience_at_round))
    

    plot(strat$comp, main=title, col="red", type = "l", lwd = 2, ylim=c(0,100), xlab="Rounds", ylab="Resilience")
    
    grid(nx = NA, ny = NULL, col = "lightgray", lty = "dotted")
    axis(2, at = seq(0, 100, by = 10), labels = seq(0, 100, by = 10)) 
    abline(h = f*100, col = "yellow", lty = 2, lwd = 2)
    labels = c(paste(stratname, "(", budget, ")", sep=""), 
        filepath)
    colors = c("red")
    locator(1) 
    legend("topright", legend = labels, box.col = "grey",col = colors, lwd = 2, xpd = TRUE)
    if (comment==""){
    comment="RAS"
    }
    
    filename = paste(Folder, "results",  sep="")
    
    print(filename)
    if (stratname=="kvs"){
        write_results(filename, expe, f, t, r, "KVS", budget, resilience_at_round$resiliences, 
            sm, resilience_at_round$rounds)
    } else if (stratname=="bm"){
        write_results(filename, expe, f, t, r, "BM", budget, resilience_at_round$resiliences, 
            sm, resilience_at_round$rounds)
    } else if (stratname=="Brahms" || stratname=="Basalt"){
        write_results(filename, expe, f, t, r, stratname, budget, resilience_at_round$resiliences, 
            0, resilience_at_round$rounds)
    } else {
        print("Error: unknown strategy")
        return
    }
    
}


sm=100
t=0
expe=0
f_values=c(1000, 2000, 3000)
r_values=c(2, 10)
budget_values=c(10, 20, 30, 40)
roundMAX=2000
Folder = "./analysis/"

for (f in f_values){
    
    for (r in r_values){
    
        params = c(10000, 160, f, t, r, sm, "kvs", 40)

        pdf(paste(Folder, "kvs-Bs-Br-", r, "-", f, ".pdf", sep="")) #, width = width, height = height)
        #par(mfrow = c(1, 1))  # 3 rows and 2 columns
        
        cms(params, "System faulty proportion  (%)")

        params = c(10000, 160, f, t, r, 0, "Brahms", 0)
        cms(params, "System faulty proportion  (%)")
        
        params = c(10000, 160, f, t, r, 0, "Basalt", 0)
        cms(params, "System faulty proportion  (%)")

        
        for (budget in budget_values){
            
            params = c(10000, 160, f, t, r, sm, "bm", budget)

            #pdf(paste(Folder, "bm-", r, "-", f, "-", budget, ".pdf", sep=""))
            
            cms(params, "System faulty proportion  (%)")

            
            expe = expe +1
        }
        dev.off()
    }
}