CIN     = "compoIN.txt"
COUT    = "compoOUT.txt"
CVIEW   = "compoVIEW.txt"
COV     = "coverage.txt"
INDEG   = "indegree.txt"
OUTDEG  = "outdegree.txt"

source("compute.r")
bags <- function(args, path, topic) {  
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
    roundMAX = 200 #as.numeric(args[10])
    folder = args[11]
    k=as.numeric(args[12])
    s=as.numeric(args[13])
    if ( strat=="KFREE"){
       strat=paste("KFREE(", k,",",s,")", sep="")
    }

    # 1. Plots
    
    name = sub(pattern = "(.*)\\..*$", replacement = "\\1", basename(path))

    ymax = 100

    rho="rho1"
    filepath1 = paste("/home/amukam/thss/simulation/Aupe/analysis/",rho, "/", 
        N, sep="")
    filepath2 = paste("/home/amukam/thss/simulation/Aupe/analysis/", rho, "/",
        N, sep="")

    strat1="aupe"
    strat2="brahms"
    brahmspath = paste(filepath1,"/", strat1,"/text",f*100, sep="")
    aupepath = paste(filepath2,"/", strat2,"/text",f*100, sep="")
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
    
    brahms$comp1=(brahms$pushBagByz)*100
    aupe$comp1=(aupe$pushBagByz)*100
    brahms$comp2=(brahms$pullBagByz)*100
    aupe$comp2=(aupe$pullBagByz)*100
    title="Aupe Brahms Bags studying"
    title=paste(title, #"\n Byzantine proportion inside push and pull bags over Time \n", 
        "f=", f*100,"% N=", N, " v=s=", v, " F=1 \n rounds=", roundNumber1)
    
    resilience1=c(tail(brahms, 1)$comp1, tail(brahms, 1)$comp2)
    resilience2=c(tail(aupe, 1)$comp1, tail(aupe, 1)$comp2)
    print(paste("resilience1",resilience1, "vs resilience2", resilience2))
    
    #PLOTS
    plot(brahms$comp1, main=paste(title, "Pushbag"), col="red", xlab="Rounds", ylab="Resilience",
        type = "l", lty=1, ylim=c(0,100))
    lines(aupe$comp1, col="blue", type = "l", lty=2)

    grid(nx = NA, ny = NULL, col = "lightgray", lty = "dotted")
    axis(2, at = seq(0, 100, by = 10), labels = seq(0, 100, by = 10)) 
    abline(h = f*100,, col = "yellow", lty = 2, lwd = 2)
    labels = c(paste("Aupe rho=1", sep=""),
            paste("Brahms rho=1", sep=""))
    colors = c("red", "blue")
    
    locator(1) 
    legend("topright", legend = labels, box.col = "grey",
    col = colors, lty=c(1,2), xpd = TRUE)

    plot(brahms$comp2, main=paste(title, "Pullbag"), col="red", xlab="Rounds", ylab="Resilience",
        type = "l", lty=1, ylim=c(0,100))
    lines(aupe$comp2, col="blue", type = "l", lty=2)

    grid(nx = NA, ny = NULL, col = "lightgray", lty = "dotted")
    axis(2, at = seq(0, 100, by = 10), labels = seq(0, 100, by = 10)) 
    abline(h = f*100,, col = "yellow", lty = 2, lwd = 2)
    labels = c(paste("Aupe rho=1", sep=""), 
            paste("Brahms rho=1", sep=""))
    colors = c("red", "blue")
    
    locator(1) 
    legend("topright", legend = labels, box.col = "grey",
    col = colors, lty=c(1,2), xpd = TRUE)
}

view <- function(args, path, topic) {  
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
    roundMAX = 200 #as.numeric(args[10])
    folder = args[11]
    k=as.numeric(args[12])
    s=as.numeric(args[13])
    if ( strat=="KFREE"){
       strat=paste("KFREE(", k,",",s,")", sep="")
    }

    # 1. Plots
    
    name = sub(pattern = "(.*)\\..*$", replacement = "\\1", basename(path))

    ymax = 100

    rho="rho1"
    filepath1 = paste("/home/amukam/thss/simulation/Aupe/analysis/",rho, "/", 
        N, sep="")
    filepath2 = paste("/home/amukam/thss/simulation/Aupe/analysis/", rho, "/",
        N, sep="")

    strat1="aupe"
    strat2="brahms"
    brahmspath = paste(filepath1,"/", strat1,"/text",f*100, sep="")
    aupepath = paste(filepath2,"/", strat2,"/text",f*100, sep="")
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
    
    brahms$comp1=(brahms$pushByzN)*100
    aupe$comp1=(aupe$pushByzN)*100
    brahms$comp2=(brahms$pullByzN)*100
    aupe$comp2=(aupe$pullByzN)*100
    brahms$comp3=(brahms$sampByzN)*100
    aupe$comp3=(aupe$sampByzN)*100
    title="Aupe Brahms view part studying"
    title=paste(title, #"\n Byzantine proportion inside parts of the view over Time \n", 
        "f=", f*100,"% N=", N, " v=s=", v, " F=10 \n rounds=", roundNumber1)
    
    resilience1=c(tail(brahms, 1)$comp1, tail(brahms, 1)$comp2, tail(brahms, 1)$comp3)
    resilience2=c(tail(aupe, 1)$comp1, tail(aupe, 1)$comp2, tail(aupe, 1)$comp3)
    print(paste("resilience1",resilience1, "vs resilience2", resilience2))
    
    #PLOTS
    plot(brahms$comp1, main=paste(title, "PushPart"), col="red", xlab="Rounds", ylab="Resilience",
        type = "l", lty=1, ylim=c(0,100))
    lines(aupe$comp1, col="blue", type = "l", lty=2)

    grid(nx = NA, ny = NULL, col = "lightgray", lty = "dotted")
    axis(2, at = seq(0, 100, by = 10), labels = seq(0, 100, by = 10)) 
    abline(h = f*100,, col = "yellow", lty = 2, lwd = 2)
    labels = c(paste("Aupe rho=1", sep=""),
            paste("Brahms rho=1", sep=""))
    colors = c("red", "blue")
    
    locator(1) 
    legend("topright", legend = labels, box.col = "grey",
    col = colors, lty=c(1,2), xpd = TRUE)

    plot(brahms$comp2, main=paste(title, "PullPart"), col="red", xlab="Rounds", ylab="Resilience",
        type = "l", lty=1, ylim=c(0,100))
    lines(aupe$comp2, col="blue", type = "l", lty=2)

    grid(nx = NA, ny = NULL, col = "lightgray", lty = "dotted")
    axis(2, at = seq(0, 100, by = 10), labels = seq(0, 100, by = 10)) 
    abline(h = f*100,, col = "yellow", lty = 2, lwd = 2)
    labels = c(paste("Aupe rho=1", sep=""), 
            paste("Brahms rho=1", sep=""))
    colors = c("red", "blue")
    
    locator(1) 
    legend("topright", legend = labels, box.col = "grey",
    col = colors, lty=c(1,2), xpd = TRUE)

    plot(brahms$comp3, main=paste(title, "SamPart"), col="red", xlab="Rounds", ylab="Resilience",
        type = "l", lty=1, ylim=c(0,100))
    lines(aupe$comp3, col="blue", type = "l", lty=2)

    grid(nx = NA, ny = NULL, col = "lightgray", lty = "dotted")
    axis(2, at = seq(0, 100, by = 10), labels = seq(0, 100, by = 10)) 
    abline(h = f*100,, col = "yellow", lty = 2, lwd = 2)
    labels = c(paste("Aupe rho=1", sep=""), 
            paste("Brahms rho=1", sep=""))
    colors = c("red", "blue")
    
    locator(1) 
    legend("topright", legend = labels, box.col = "grey",
    col = colors, lty=c(1,2), xpd = TRUE)
}
