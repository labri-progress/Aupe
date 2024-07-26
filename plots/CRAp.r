#!/usr/bin/env Rscript
args = commandArgs(trailingOnly=TRUE)

CIN     = "compoIN.txt"
COUT    = "compoOUT.txt"
CVIEW   = "compoVIEW.txt"
COV     = "coverage.txt"
INDEG   = "indegree.txt"
OUTDEG  = "outdegree.txt"
SAMPLE = "sample.txt"
ARR     = "globalarray.txt"


library(miscTools)

source("aupe.r")
#source("test.r")
n_values = c(10000) #10000

#f_values=seq(0.06, 0.5, by = 0.02)
f_values= c(0.08, 0.10, 0.12, 0.14, 0.16, 0.18, 0.20, 
    0.22, 0.24, 0.26, 0.28, 0.30, 0.32, 0.34, 0.36, 0.38, 0.40,
    0.42, 0.44, 0.46, 0.48, 0.50 ) #c(0.06, 0.10, 0.14, 0.18, 0.20, 0.24, 0.30, 0.36, 0.40, 0.50)

print(args)
print(f_values)
thrshold = 0 #as.numeric(args[1])
#rep = as.integer(args[2])
rep=1
strat = "basalt-simple"
merge = "no"
Method = "moy"
gamma = 0.3
rMAX = 400
k=500
s=100
expe=0
sm=100

local1 = "machines"
local2 = "serveur9/data"
local = "data"  
for (n in n_values){
    if (n==1000 ){
        v= 100
    }else{
        v=160
    }
        
    folder = paste("../analysis/rho1/", n, sep="")

    for (f in f_values){
        
        print(paste("Expe", expe, sep=""))
        params = c(n, v, f, 0, sm, expe, strat, merge, gamma, 
            rMAX, folder, k, s)

        pdf(paste(folder, "/expe", expe, ".pdf", sep=""))
        par(mfrow = c(1, 1))  # 3 rows and 2 columns
        #par(mfrow = c(3, 2))        
        #compute(params, CIN, "Input streams faulty proportion (%)")
        #compute(params, COUT, "Output stream faulty proportion  (%)")
        compute(params, CVIEW, "System faulty proportion  (%)")
        #compute(params, SAMPLE, "Sample faulty proportion  (%)")

        dev.off()
        expe=expe+1
    }
    dev.off()
}
print("NEXT")
#print(warnings()