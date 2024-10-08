CIN     = "compoIN.txt"
COUT    = "compoOUT.txt"
CVIEW   = "compoVIEW.txt"
COV     = "coverage.txt"
INDEG   = "indegree.txt"
OUTDEG  = "outdegree.txt"

library(zoom)
detect_first_convergence_index <- function(values, f, rounds) {
    threshold1 <- 75*f # f-25% threshold
    threshold2 <- 125*f # f+25% threshold
    n <- length(values)
    #print(paste("n =", n, "threshold1 =", threshold1, "threshold2 =", threshold2))
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
write_results <- function(filename, expe, f, strat,
    resilience, sm, ttC, roundNumber, comment, name) {
    file.info(filename)$size
    if (!file.exists(filename)) {
       head <- "Expe     faulty     Strat     resilience     ttC     sm     round     comment"
        if(name == COV){
            head <- "Expe faulty SMemory Strat coverage round comment"
        }
        write(head, append=TRUE, file = filename)
    }
    separator = "        "
    sol = paste(expe, f*100, strat, resilience, ttC, sm, roundNumber, comment, sep = separator)
    write(sol, append=TRUE, file = filename)
}

compute <- function(args, path, topic) {  
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
    s=as.numeric(args[13])
    if ( strat=="KFREE"){
       strat=paste("KFREE(", k,",",s,")", sep="")
    }

    # 1. Plots
    
    name = sub(pattern = "(.*)\\..*$", replacement = "\\1", basename(path))

    ymax = 100
    strat1 = "brahms"
    strat2 ="aupe"

    filepath = paste("/home/amukam/thss/simulation/aupe/analysis/", 
        N, sep="")
    brahmspath = paste(filepath,"/", strat1,"/expe", expe, 
        "text",f*100, sep="")
    aupepath = paste(filepath,"/", strat2,"/expe", expe, 
        "text",f*100, sep="")
    print(brahmspath)
    print(aupepath)
    
    brahms <- read.table(brahmspath, header = TRUE)
    roundNumber1 <- nrow(brahms)
    aupe <- read.table(aupepath, header = TRUE)
    roundNumber2 <- nrow(aupe)
    print(paste("roundNumber1",roundNumber1, "vs roundNumber2", roundNumber2))
    comment="" # for logging
    missing = roundMAX +1 - roundNumber1 # round of initialisation
    if (missing != 0) {
        print(c(nrow(brahms), ncol(brahms)))
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
        brahms$comp=(brahms$avgByzN/v)*100
        aupe$comp=(aupe$avgByzN/v)*100
        title=paste("Byzantine proportion inside view over Time f=", 
            f*100,"%  
            N=", N, " v=s=", v, " F=10 \n alpha=beta=gamma=1/3 rounds=", roundNumber1)
    }else if(path == SAMPLE){
        brahms$comp=(brahms$avgByzSamp/v)*100
        aupe$comp=(aupe$avgByzSamp/v)*100
        title="Byzantine proportion inside sample over Time"
    }else {
        title="Evolution of coverage over Time"
    }
    
    resilience1=tail(brahms, 1)$comp
    resilience2=tail(aupe, 1)$comp
    print(paste("resilience1",resilience1, "vs resilience2", resilience2))
    
    plot(brahms$comp, main=title, col="red", type = "l", lwd = 2, ylim=c(0,100))
    if (path == CVIEW|| path==SAMPLE){
        lines(aupe$comp, col="blue", type = "l", lwd = 2)
    }
    grid(nx = NA, ny = NULL, col = "lightgray", lty = "dotted")
    axis(2, at = seq(0, 100, by = 10), labels = seq(0, 100, by = 10)) 
    abline(h = f*100,, col = "yellow", lty = 2, lwd = 2)
    if (path == CVIEW|| path==SAMPLE){
        labels = c(paste("Brahms ", sep=""), paste("Aupe sm=", sm, sep=""))
        colors = c("red", "blue")
        locator(1) 
        legend("topright", legend = labels, box.col = "grey",
        col = colors, lwd = 2, xpd = TRUE)
    }
    
    # Detect the first index of convergence
    if (path == CVIEW){
        ttc0 <- detect_first_convergence_index(brahms$comp, f, roundNumber1)
        ttc1 <- detect_first_convergence_index(aupe$comp, f, roundNumber2)
    
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
        
        filename = paste(folder, "/","dsn", name,  sep="")
        
        #print("write_results4")
        write_results(filename, expe, f, "Brahms", resilience1, 0,
            ttc0, roundNumber1, comment, name)
        write_results(filename, expe, f, "Aupe", resilience2, sm,
            ttc1, roundNumber2, comment, name)
    }
}
