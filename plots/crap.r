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

n_values = c(10000) #10000


all_f_values= c(0.08, 0.10, 0.12, 0.14, 0.16, 0.18, 0.20, 
    0.22, 0.24, 0.26, 0.28, 0.30, 0.32, 0.34, 0.36, 0.38, 0.40,
    0.42, 0.44, 0.46, 0.48, 0.50 ) #c(0.06, 0.10, 0.14, 0.18, 0.20, 0.24, 0.30, 0.36, 0.40, 0.50)

#strats = c("aupe-merge", "aupe-global", "aupe", 
strats = c("aupe-global", "aupe-merge-sup10", "aupe", 
"basalt-simple", "brahms")
f_values=c(0.10, 0.12, 0.14, 0.16, 0.18, 0.20, 
    0.22, 0.24, 0.26, 0.28, 0.30, 0.32, 0.34, 0.36, 0.38, 0.40,
    0.42, 0.44, 0.46, 0.48, 0.50 )
     #c(0.22) #c(0.10,0.20, 0.30, 0.40, 0.50)  #c(0.22, 0.24, 0.26, 0.28) #c(0.22) #c(0.10,0.20, 0.30, 0.40, 0.50) #all_f_values

f_values= seq(0.2, 0.3, by=0.02) #c(0.22) #, 0.26, 0.34) #all_f_values

k=0 #as.integer(args[1])
print(paste("rho",k))
if (k==0) {
    f_values =  c(0.2, 0.22, 0.24, 0.26, 0.28, 0.3, 0.34, 0.40, 0.50)
}else {
    f_values =  c(0.08, 0.1, 0.12, 0,14, 0.2, 0.22, 0.24, 0.26, 0.28, 0.3, 0.34, 0.40, 0.50)
}

f_values= seq(0.2, 0.3, by=0.02)
f_values = all_f_values

f_values=c(0.3)
print(args)
print(f_values)
thrshold = 0 #as.numeric(args[1])
#rep = as.integer(args[2])
rep=1
strat1 =  "aupe-merge-sup10"
strat2 =  "aupe-merge-sup30"
strat=strats[2]
merge = "yes"
Method = "moy"
gamma = 0.3
rMAX = 200

#print(paste("rho",k))
r=1
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
            rMAX, folder, k, r)

        pdf(paste(folder, "/expe", expe, ".pdf", sep=""), width = width, height = height)
        #par(mfrow = c(1, 1))  # 3 rows and 2 columns
        
        #rho(params, CVIEW, "System faulty proportion  (%)")
        if(strat == strats[2] ) {#"aupe-merge" && FALSE){
            source("studyAupeT.r")#source("studyAupeT.r")
            #bags(params, BAGS, "Stream Bags faulty proportion (%)")
            #view(params, PVIEW, "Parts of the view faulty proportion  (%)")
        }
        if(strat == strats[2]) { #"aupe-merge" && FALSE){
            source("trusted.r")
            trust(params, CVIEW, "Study of Aupe-mergeT ")
        }
        if(strat == "aupe-merge" && TRUE){
            source("comparaison.r")
            params = c(n, v, f, 0, sm, expe, strat, merge, gamma, 
            rMAX, folder, k, r)
            #comp(params, CVIEW, "Study of Aupe-mergeT ")
        }
       
        dev.off()
        expe=expe+1
    }
}
print("NEXT")
#print(warnings()