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


library(miscTools)

source("aupe.r")

n_values = c(1000) #10000

all_f_values= c(0.08, 0.10, 0.12, 0.14, 0.16, 0.18, 0.20, 
    0.22, 0.24, 0.26, 0.28, 0.30, 0.32, 0.34, 0.36, 0.38, 0.40,
    0.42, 0.44, 0.46, 0.48, 0.50 ) #c(0.06, 0.10, 0.14, 0.18, 0.20, 0.24, 0.30, 0.36, 0.40, 0.50)

m = as.integer(args[1])

strats = c(paste("cms-merge-sup", m, sep=""), paste("aupe-merge-sup", m, sep=""))
f_values=c(0.10, 0.12, 0.14, 0.16, 0.18, 0.20, 
    0.22, 0.24, 0.26, 0.28, 0.30, 0.32, 0.34, 0.36, 0.38, 0.40,
    0.42, 0.44, 0.46, 0.48, 0.50 )
     #c(0.22) #c(0.10,0.20, 0.30, 0.40, 0.50)  #c(0.22, 0.24, 0.26, 0.28) #c(0.22) #c(0.10,0.20, 0.30, 0.40, 0.50) #all_f_values

#f_values = all_f_values

f_values=c(0.08, 0.10, 0.20, 0.24, 0.30, 0.40, 0.50)
print(args)
print(f_values)
thrshold = 0 #as.numeric(args[1])
#rep = as.integer(args[2])
rep=1

merge = "yes"
Method = "moy"
gamma = 0.3
rMAX = 200

#CMS
k=272
s=272 #10

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
for (n in n_values){
    v=20
        
    folder = paste("../analysis/", n, sep="")

    for (f in f_values){
        for (t in t_values){
            params = c(n, v, f, t, sm, strats[1], strats[2], #merge, gamma, 
                rMAX, folder, k, s, m)

            pdf(paste(folder, "/expe", expe, ".pdf", sep="")) #, width = width, height = height)
            #par(mfrow = c(1, 1))  # 3 rows and 2 columns
            
            cms(params, CVIEW, "System faulty proportion  (%)")
        
            dev.off()
            expe = expe +1
            #quit()
        }
        
    }
}
print("NEXT")
#print(warnings()