#!/usr/bin/env Rscript
args = commandArgs(trailingOnly=TRUE)

#install.packages('tidyverse')
#test if there is at least one argument: if not, return an error
if (length(args)==0) {
  args[1] = 0 # expe number 
  args[2] = 10000 # N
  args[3] = 200 # V
  args[4] = 0.10 #f
  args[5] = 450 #sm
  args[6] = "OMN" # start
  args[7] = "NO" #merge
  args[8] = 0.2 #gamma
  args[9] = 150 #rnd
  args[10] = 0.10 #t
}
# EXAMPLE: 
# Rscript test.r 0 1000 20 0.30 100 OMN NO 0.4 150 0
# Rscript test.r 1 1000 20 0.30 100 OMN NO 0.375 150 0
# Rscript test.r 2 10000 50 0.30 100 OMN NO 0.35 150 0

print(paste("Arguments", args))

library(stringr)
library(dplyr)

source("compute.r")

CIN     = "compoIN.txt"
COUT    = "compoOUT.txt"
CVIEW   = "compoVIEW.txt"
COV     = "coverage.txt"
INDEG   = "indegree.txt"
OUTDEG  = "outdegree.txt"
ARR     = "globalarray.txt"
SAMPLE = "sample.txt"

expe = as.numeric(args[1])
n = as.numeric(args[2])
v = as.numeric(args[3])
f = as.double(args[4])
sm = as.numeric(args[5])
strat = args[6]
merge = args[7]
gamma= as.double(args[8])
rMAX= as.numeric(args[9])
t = as.double(args[10])
k = as.double(args[11])
s = as.double(args[12])

folder = paste("../analysis/", n, sep="")
#folder = paste("../data/expe", expe, "/", sep="")
params = c(n, v, f, t, sm, expe, strat, merge, gamma, 
  rMAX, folder, k, s)


pdf(paste(folder, "/expe", expe, ".pdf", sep=""))
par(mfrow = c(1, 1))  # 3 rows and 2 columns
#par(mfrow = c(3, 2))        
#compute(params, CIN, "Input streams faulty proportion (%)")
#compute(params, COUT, "Output stream faulty proportion  (%)")
compute(params, CVIEW, "System faulty proportion  (%)")
compute(params, SAMPLE, "Sample faulty proportion  (%)")
#compute(params, COV, "Coverage proportion  (%)")


dev.off()
#Rscript test.r 2 10000 50 0.50 300 OMN YES 0.2 20000 1
