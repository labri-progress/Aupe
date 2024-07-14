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
AP = as.double(args[2])
print(paste("AP", AP))
# EXAMPLE: Rscript CRAp.r 0 1 OMN NO MOY
# 1.params
# 2. folder


library(miscTools)

source("utils.r")

add <- function(t, merge){
     if (merge =="YES"){
        additionnal = paste("M", format(round(AP,2), nsmall = 2),
        "-", format(round(t,2), nsmall = 2), sep="")
    }else {
        additionnal = format(round(AP,2), nsmall = 2)
    }
    if (t==0){
        additionnal = format(round(AP,2), nsmall = 2)
    }
    print(additionnal)
    return(additionnal)
}

detect_first_convergence_index2 <- function(values, f) {
    threshold1 <- 75*f # f-25% threshold
    threshold2 <- 125*f # f+25% threshold
    n <- length(values)
    print(paste("n =", n, "threshold1 =", threshold1, 
        "threshold2 =", threshold2))
    i <-20
    while (i < n) {
        if (values[i] >= threshold1 && values[i] <= threshold2) {
            print(paste("index =", i))
            return(i)
        }
        i <- i+1
    }
    #print(values)
    return(round_MAX)  # Return Round max if no convergence is found
}

detect_first_convergence_index <- function(values, f, rounds) {
    threshold1 <- 75*f # f-25% threshold
    threshold2 <- 125*f # f+25% threshold
    n <- length(values)
    print(paste("n =", n, "threshold1 =", threshold1, 
        "threshold2 =", threshold2))
    i <-1
    flag <- FALSE
    while (i < n) {
        if (values[i] >= threshold1 && values[i] <= threshold2) {
            #print(paste("index =", i))
            if (!flag) {
                index = i
            }
            flag <- TRUE
        }else{
            flag <- FALSE
        }
        i <- i+1
    }
    if (flag){
        return(index)
    }else {
        return(rounds)  # Return Round max if no convergence is found
    }
    
}
compute <- function(args, path, topic) {  
    # 0. Data      
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
    s=as.numeric(args[13])
    #method = args[14]
    
    datam0 = read.table(paste(folder, "0.00", 
        path, sep=""), sep=' ', header=FALSE)

    t=0
    data0 = read.table(paste(folder, add(t, merge),
        path, sep=""), sep=' ', header=FALSE)

   
    datam0 = t(datam0[,-length(datam0)])
    data0 = t(data0[,-length(data0)])

    roundNumberm0 <- ncol(datam0)
    roundNumber0 <- ncol(data0)

    roundNumber = roundNumber0
    commentm0 <- missing_files("-1", datam0, N, f)
    comment0 <- missing_files("0", data0, N, f)

    commentm0 <- missing_round("-1", commentm0, roundMAX, roundNumberm0)
    comment0 <- missing_round("0", comment0, roundMAX, roundNumber0)
    method = "MOY"
    print(paste("Method", method))
    if (method == "MED") {
        meansm0 <- colMedians(datam0)
        means0 <- colMedians(data0)
    }else {
        meansm0 <- colMeans(datam0)
        means0 <- colMeans(data0)
    }
    # temporary
    # Original vector of size 400
    # Replicate the last element to fill the vector to size 1000
    if (roundNumberm0 < roundNumber){
        completed_vector <- c(meansm0, rep(tail(meansm0, 1), round_MAX - length(meansm0)))
        meansm0 <-completed_vector
    }
    
    df<- data.frame(meansm0, means0) 
    
    name=sub(pattern = "(.*)\\..*$", replacement = "\\1", basename(path))

    ## Title
    text1 = paste("N=", N, " v=", v, " f=", f*100, "% AP=", AP*100, 
        "% de C", sep="")
    
    text2 = paste("sm=", sm," gamma=", gamma," rnd=", roundNumber, sep="")
    text3 = paste("strat=", strat, sep="")
    print(method)
    main_title = paste("E", expe, "(", method, ") ", 
        topic, sep="")
    if (path == CVIEW){
        title = paste(main_title, "\n", text1, "\n", text2, text3)
    }else{
        title = topic
    }
    
    ymax=100
    if (path == INDEG || path == OUTDEG){
        ymax=ymax+v
    }
    #mean(data[,ncol(data)])
    resiliencem0 = mean(datam0[,ncol(datam0)])
    resilience0 = mean(data0[,ncol(data0)])

    print("test_resilience")
    test_resilience(resiliencem0, meansm0)
    test_resilience(resilience0, means0)
    
    lwd=1
    plot(df$meansm0, main=title, ylim=c(0,ymax), type = "l", col="gray",
        ylab=paste(topic, sep=""), xlab="Rounds", lwd=lwd)
        
    axis(2, at = seq(0, 100, by = 10), labels = seq(0, 100, by = 10))
    # Ajouter des lignes de grille horizontales
    abline(h = seq(0, 100, by = 10), col = "gray", lty = "dotted")

    # Add y = x
    #abline(a = 0, b = 1, col = "green", lwd = 2)
    # Add y = c
   
    
    lines(df$means0, col="black", lwd=lwd) 

    labels = c(paste("f=", f*100, "%, Brahms", sep=""), paste("f=", f*100, "%, Aupe", sep=""))
        #paste("f=", f*100, "%, t=0% ", sep=""))
    colors = c("gray", "black")
    locator(1) 
    legend("topright", legend = labels, box.col = "grey",
       col = colors, lwd = lwd, xpd = TRUE)
    
    commentm0 <- test_ejection(commentm0, resiliencem0)
    comment0 <- test_ejection(comment0, resilience0)

    commentm0 <- fill_comment(commentm0)
    comment0 <- fill_comment(comment0)

    # Detect the first index of convergence
    ttcm0 <- detect_first_convergence_index(meansm0, f, roundNumberm0)
    ttc0 <- detect_first_convergence_index(means0, f, roundNumber0)

    print(paste("ttc are", ttcm0, " and ", ttc0))

    system = paste("N=", N, " v=",  v, sep="")
    study = paste("strat=", strat, sep="")
    mainDir = "../results/"
    dir.create(file.path(mainDir, system)) # check folder existence
    new = paste(mainDir, system, sep="")
    dir.create(file.path(new, study))
    
    filename = paste(mainDir, system, "/", study, "/","dsn", name,  sep="")
    
    #print("write_results4")
    write_results5(filename, expe, f, 0, 0, sm, strat, resiliencem0,
        ttcm0, roundNumberm0, commentm0, name)
    write_results5(filename, expe, f, 0, AP, sm, strat, resilience0,
        ttc0, roundNumber0, comment0, name)
}

n_values = c(10000) #10000

#f_values=seq(0.06, 0.5, by = 0.02)
f_values= c(0.1, 0.15, 0.2 ) #0.06, 0.10, 0.14, 0.18, 0.20, 0.24, 0.30, 0.36, 0.40, 0.50 ) #c(0.06, 0.10, 0.14, 0.18, 0.20, 0.24, 0.30, 0.36, 0.40, 0.50)

print(args)
print(f_values)
thrshold = as.numeric(args[1])
#rep = as.integer(args[2])
rep=1
strat = args[3]
merge = args[4]
Method = args[5]
gamma = 0.2
round_MAX = 400
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
        
    folder = paste("../", local, "/", sep="")
    if (Method == "MED") {
        name = paste(folder, "expeAP", AP, "_med_", merge, ".pdf", sep="")
    }else {
        name = paste(folder, "expeAP", AP,"_", merge, ".pdf", sep="")
    }
    pdf(name, height = 10) #width = 10
    par(mfrow = c(3, 2))  # 3 rows and 2 columns

    for (f in f_values){
        
        for (a in 1:rep){
            if (expe<thrshold) {
                print(paste("EXPE", expe,"!"))
                expe=expe+1
                next
            }else {
                print(paste("***************** EXPE", n," ", v, " ", f , " expe ", expe, "*****************"))
                folder = paste("../", local,"/expe", expe, "/", sep="")
                params = c(n, v, f, 0, sm, expe, strat, merge, gamma, 
                    round_MAX, folder, k, s, Method)
                
                compute(params, CVIEW, "System faulty proportion  (%)")
            }
                #print("NEXT")
                expe=expe+1
        } 
    }
    dev.off()
}
print("NEXT")
#print(warnings())