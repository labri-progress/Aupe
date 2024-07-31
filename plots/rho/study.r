CIN     = "compoIN.txt"
COUT    = "compoOUT.txt"
CVIEW   = "compoVIEW.txt"
COV     = "coverage.txt"
INDEG   = "indegree.txt"
OUTDEG  = "outdegree.txt"

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

    filepath1 = paste("/home/amukam/thss/simulation/Aupe/analysis/rho1/", 
        N, sep="")
    filepath2 = paste("/home/amukam/thss/simulation/Aupe/analysis/rho0/", 
        N, sep="")
    brahmspath = paste(filepath1,"/", strat,"/text",f*100, sep="")
    aupepath = paste(filepath2,"/", strat,"/text",f*100, sep="")
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
    if (strat=="aupe-merge"){
        title="aupe merge=YES"
    }else {
        title="aupe merge=NO"
    }
    title=paste(title, " Byzantine proportion inside push and pull bags over Time \n", 
        "f=", f*100,"% N=", N, " v=s=", v, " F=1 \n alpha=beta=gamma=1/3 rounds=", roundNumber1)
    
    resilience1=c(tail(brahms, 1)$comp1, tail(brahms, 1)$comp2)
    resilience2=c(tail(aupe, 1)$comp1, tail(aupe, 1)$comp2)
    print(paste("resilience1",resilience1, "vs resilience2", resilience2))
    
    plot(brahms$comp1, main=paste(title, "rho=1"), col="red", xlab="Rounds", ylab="Resilience",
        type = "l", lty=1, ylim=c(0,100))
    lines(brahms$comp2, col="red", type = "l", lty=2)

    grid(nx = NA, ny = NULL, col = "lightgray", lty = "dotted")
    axis(2, at = seq(0, 100, by = 10), labels = seq(0, 100, by = 10)) 
    abline(h = f*100,, col = "yellow", lty = 2, lwd = 2)
    labels = c(paste("pushbag rho=1", sep=""),
            paste("pullbag rho=1", sep=""))
    colors = c("red", "red")
    
    locator(1) 
    legend("topright", legend = labels, box.col = "grey",
    col = colors, lty=c(1,2), xpd = TRUE)

    plot(aupe$comp1, main=paste(title, "rho=0"), col="blue", xlab="Rounds", ylab="Resilience",
        type = "l", lty=1, ylim=c(0,100))
    lines(aupe$comp2, col="blue", type = "l", lty=2)

    grid(nx = NA, ny = NULL, col = "lightgray", lty = "dotted")
    axis(2, at = seq(0, 100, by = 10), labels = seq(0, 100, by = 10)) 
    abline(h = f*100,, col = "yellow", lty = 2, lwd = 2)
    labels = c(paste("pushbag rho=0", sep=""), 
            paste("pullbag rho=0", sep=""))
    colors = c("blue", "blue")
    
    locator(1) 
    legend("topright", legend = labels, box.col = "grey",
    col = colors, lty=c(1,2), xpd = TRUE)

    # Detect the first index of convergence
    if (path == CVIEW){
        ttc0 <- detect_first_convergence_index(brahms$comp, f, roundNumber1)
        ttc1 <- detect_first_convergence_index(aupe$comp, f, roundNumber2)
    
        # 2. Logs
        
        if (comment==""){
        comment="RAS"
        }
        system = paste("N=", N, " v=",  v, sep="")
        study = paste("strat=", strat1, sep="")
        mainDir = "../results/"
        dir.create(file.path(mainDir, system)) # check folder existence
        new = paste(mainDir, system, sep="")
        dir.create(file.path(new, study))
        
        filename = paste(new, "/","dsn", name,  sep="")
        
        #print("write_results4")
        write_results(filename, expe, f, paste(strat, "rho1", sep=""), resilience1, 0,
            ttc0, roundNumber1, comment, name)
        write_results(filename, expe, f, paste(strat, "rho0", sep=""), resilience2, sm,
            ttc1, roundNumber2, comment, name)
    }
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

    filepath1 = paste("/home/amukam/thss/simulation/Aupe/analysis/rho1/", 
        N, sep="")
    filepath2 = paste("/home/amukam/thss/simulation/Aupe/analysis/rho0/", 
        N, sep="")
    brahmspath = paste(filepath1,"/", strat,"/text",f*100, sep="")
    aupepath = paste(filepath2,"/", strat,"/text",f*100, sep="")
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
    if (strat=="aupe-merge"){
        title="aupe merge=YES"
    }else {
        title="aupe merge=NO"
    }
    title=paste(title, " Byzantine proportion inside parts of the view over Time \n", 
        "f=", f*100,"% N=", N, " v=s=", v, " F=10 \n alpha=beta=gamma=1/3 rounds=", roundNumber1)
    
    resilience1=c(tail(brahms, 1)$comp1, tail(brahms, 1)$comp2, tail(brahms, 1)$comp3)
    resilience2=c(tail(aupe, 1)$comp1, tail(aupe, 1)$comp2, tail(aupe, 1)$comp3)
    print(paste("resilience1",resilience1, "vs resilience2", resilience2))
    
    plot(brahms$comp1, main=paste(title, "rho=1"), col="red", xlab="Rounds", ylab="Resilience",
        type = "l", lty=1, ylim=c(0,100))
    lines(brahms$comp2, col="red", type = "l", lty=2)
    lines(brahms$comp3, col="red", type = "l", lty=3)

    grid(nx = NA, ny = NULL, col = "lightgray", lty = "dotted")
    axis(2, at = seq(0, 100, by = 10), labels = seq(0, 100, by = 10)) 
    abline(h = f*100,, col = "yellow", lty = 2, lwd = 2)
    labels = c(paste("pushpart rho=1", sep=""), 
            paste("pullpart rho=1", sep=""), 
            paste("samppart rho=1", sep=""))
    colors = c("red", "red", "red")
    
    locator(1) 
    legend("topright", legend = labels, box.col = "grey",
    col = colors, lty=c(1,2,3), xpd = TRUE)

    plot(aupe$comp1, main=paste(title, "rho=0"), col="blue", xlab="Rounds", ylab="Resilience",
        type = "l", lty=1, ylim=c(0,100))
    lines(aupe$comp2, col="blue", type = "l", lty=2)
    lines(aupe$comp3, col="blue", type = "l", lty=3)

    grid(nx = NA, ny = NULL, col = "lightgray", lty = "dotted")
    axis(2, at = seq(0, 100, by = 10), labels = seq(0, 100, by = 10)) 
    abline(h = f*100,, col = "yellow", lty = 2, lwd = 2)
    labels = c(paste("pushpart rho=0", sep=""), 
            paste("pullpart rho=0", sep=""),
            paste("samppart rho=0", sep=""))
    colors = c("blue", "blue", "blue")
    
    locator(1) 
    legend("topright", legend = labels, box.col = "grey",
    col = colors, lty=c(1,2,3), xpd = TRUE)

    # Detect the first index of convergence
    if (path == CVIEW){
        ttc0 <- detect_first_convergence_index(brahms$comp, f, roundNumber1)
        ttc1 <- detect_first_convergence_index(aupe$comp, f, roundNumber2)
    
        # 2. Logs
        
        if (comment==""){
        comment="RAS"
        }
        system = paste("N=", N, " v=",  v, sep="")
        study = paste("strat=", strat1, sep="")
        mainDir = "../results/"
        dir.create(file.path(mainDir, system)) # check folder existence
        new = paste(mainDir, system, sep="")
        dir.create(file.path(new, study))
        
        filename = paste(new, "/","dsn", name,  sep="")
        
        #print("write_results4")
        write_results(filename, expe, f, paste(strat, "rho1", sep=""), resilience1, 0,
            ttc0, roundNumber1, comment, name)
        write_results(filename, expe, f, paste(strat, "rho0", sep=""), resilience2, sm,
            ttc1, roundNumber2, comment, name)
    }
}
