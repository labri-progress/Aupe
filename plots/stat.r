#!/usr/bin/env Rscript
args = commandArgs(trailingOnly=TRUE)

PVIEW     = "partView"
BAGS    = "bags"
CVIEW   = "compoVIEW.txt"
COV     = "coverage.txt"
INDEG   = "indegree.txt"
OUTDEG  = "outdegree.txt"
SAMPLE = "sample.txt"
ARR     = "globalarray.txt"

# Rscript stat.r 10
library(miscTools)

source("compute.r")

write_results <- function(filename, expe, f, t, strat, dim,
    resilience, sm, ttC, roundNumber, comment) {
    file.info(filename)$size
    if (!file.exists(filename)) {
       head <- "Expe     faulty     trusty     Strat     dim     resilience     ttC     sm     round     comment"
        write(head, append=TRUE, file = filename)
    }
    separator = "        "
    sol = paste(expe, f*100, t*100, strat, dim, resilience, ttC, sm, roundNumber, comment, sep = separator)
    write(sol, append=TRUE, file = filename)
}

stat <- function(args, path, topic) {  
    # 0. Data      
    #print(path)
    N = as.numeric(args[1])
    v = as.numeric(args[2])
    f = as.numeric(args[3])
    t = as.numeric(args[4])
    sm = as.numeric(args[5])
    stratname = args[6]
    roundMAX = as.double(args[7])
    folder = args[8]
    k=as.numeric(args[9])
    s=as.numeric(args[10])
    m=as.numeric(args[11])

    print(args)
    # 1. Plots
    
    name = sub(pattern = "(.*)\\..*$", replacement = "\\1", basename(path))
    print(name)
    ymax = 100
    
    filepath = paste("/home/amukam/thss/simulation/Aupe/analysis/", N, sep="")
    stratpath = paste(filepath,"/", stratname,"/text",f*100, sep="")
    if (t!=0){
        stratpath = paste(stratpath,"-",t*100, sep="")
    }
    print(stratpath)
    
    strat <- read.table(stratpath, header = TRUE)
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
    if (path == CVIEW){
        strat$comp=(strat$avgByzN/v)*100
        title=paste("Byzantine proportion inside view over Time f=", 
            f*100,"%","  t=", t*100,"%  
            N=", N, " v=s=", v, " m=", m, " F=10 rounds=", roundNumber1, sep="")
    }else if(path == SAMPLE){
        strat$comp=(strat$avgByzSamp/v)*100
        title="Byzantine proportion inside sample over Time"
    }else {
        title="Evolution of coverage over Time"
    }
    
    resilience1=tail(strat, 1)$comp
    print(paste("resilience1",resilience1))
    
    plot(strat$comp, main=title, col="red", type = "l", lwd = 2, ylim=c(0,100), xlab="Rounds", ylab="Resilience")
    
    grid(nx = NA, ny = NULL, col = "lightgray", lty = "dotted")
    axis(2, at = seq(0, 100, by = 10), labels = seq(0, 100, by = 10)) 
    abline(h = f*100, col = "yellow", lty = 2, lwd = 2)

    # Detect the first index of convergence
    if (path == CVIEW){
        ttc0 <- detect_first_convergence_index(strat$comp, f, roundNumber1)
    
        if (comment==""){
        comment="RAS"
        }
        param = paste("m=", m, sep="")
        system = paste("N=", N, " v=",  v, sep="")
        mainDir = "../results/"
        dir.create(file.path(mainDir, param))
        new = paste(mainDir, param, sep="")
        dir.create(file.path(new, system)) 
        new = paste(new, "/", system, sep="")
        
        print(paste("name", name))
        filename = paste(new, "/", name,  sep="")
        
        print(filename)
        dim = paste("serie(", s, ",", k, ")", sep="")
        write_results(filename, expe, f, t, stratname, dim, resilience1, sm,
            ttc0, roundNumber1, comment) 
        
    }
}


n=10000
v=160

m = as.integer(args[1])

strat = paste("serie-merge-sup", m, sep="") #paste("cms-merge-sup", m, sep="")

f_values=c(0.08, 0.10, 0.20, 0.24, 0.30, 0.40, 0.50)
print(args)
print(f_values)
thrshold = 0 
rep=1

merge = "yes"
Method = "moy"
gamma = 0.3
rMAX = 200

#CMS
k=1000
s=10

t_values=c(0, 0.01, 0.1)
expe=0
sm=100
local1 = "machines"
local2 = "serveur9/data"
local = "data"  
partview=FALSE
if (as.integer(args[1])==1){
    partview=TRUE
    ratio <- 0.75
}else{
    ratio <- 16 / 9
}
width <- 8   # largeur en pouces
height <- width / ratio
expe = 0
folder = paste("../analysis/", n, sep="")

for (f in f_values){
    for (t in t_values){
        params = c(n, v, f, t, sm, strat, #merge, gamma, 
            rMAX, folder, k, s, m)

        pdf(paste(folder, "/expe", expe, ".pdf", sep="")) #, width = width, height = height)
        #par(mfrow = c(1, 1))  # 3 rows and 2 columns
        
        stat(params, CVIEW, "System faulty proportion  (%)")
    
        dev.off()
        expe = expe +1
        #quit()
    }
}
print("NEXT")
#print(warnings()