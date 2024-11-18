CIN     = "compoIN.txt"
COUT    = "compoOUT.txt"
CVIEW   = "compoVIEW.txt"
COV     = "coverage.txt"
INDEG   = "indegree.txt"
OUTDEG  = "outdegree.txt"

source("compute.r")
source("viewT.r")
write_results <- function(filename, expe, f, strat, rho,
    resilience, part, sm, ttC, roundNumber, comment, name) {
    file.info(filename)$size
    if (!file.exists(filename)) {
       head <- "Expe     faulty     Strat     rho     resilience     part     ttC     sm     round     comment"
        if(name == COV){
            head <- "Expe faulty SMemory Strat coverage round comment"
        }
        write(head, append=TRUE, file = filename)
    }
    separator = "        "
    sol = paste(expe, f*100, strat, rho, resilience, part, ttC, sm, roundNumber, comment, sep = separator)
    write(sol, append=TRUE, file = filename)
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
    roundMAX = as.numeric(args[10])
    folder = args[11]
    k=as.numeric(args[12])
    r=as.numeric(args[13])

    # 1. Plots
    
    ymax = 100

    rho=paste("rho",k/r, sep="")
    print(rho)
    filepath = paste("/home/amukam/thss/simulation/Aupe/analysis/",rho, "/", 
        N, sep="")
    t1=10
    t2=20
    t3=30
    path1 = paste(filepath,"/", strat,"/text",f*100,"-", t1, sep="")
    path2 = paste(filepath,"/", strat,"/text",f*100,"-", t2, sep="")
    path3 = paste(filepath,"/", strat,"/text",f*100,"-", t3, sep="")
    
    print(path1)
    print(path2)
    print(path3)

    strat1="brahms"
    strat2="aupe"
    strat3="aupe-global"
    brahmspath = paste(filepath,"/", strat1,"/text",f*100, sep="")
    aupepath = paste(filepath,"/", strat2,"/text",f*100, sep="")
    mergepath = paste(filepath,"/", strat3,"/text",f*100, sep="") #paste(filepath,"/", strat3,"/text",f*100, sep="")
    print(brahmspath)
    print(aupepath)
    #print(mergepath)
    
    brahms <- read.table(brahmspath, header = TRUE)
    roundNumber11 <- nrow(brahms)
    aupe <- read.table(aupepath, header = TRUE)
    roundNumber22 <- nrow(aupe)
    merge <- read.table(mergepath, header = TRUE)
    roundNumber33 <- nrow(merge)

    merge1 <- read.table(path1, header = TRUE)
    roundNumber1 <- nrow(merge1)
    merge2 <- read.table(path2, header = TRUE)
    roundNumber2 <- nrow(merge2)
    merge3 <- read.table(path3, header = TRUE)
    roundNumber3 <- nrow(merge3)

    print(paste("roundNumber1",roundNumber1, "vs roundNumber2", roundNumber2,
    "and roundNumber3", roundNumber3))
    comment="" # for logging
    missing = roundMAX +1 - roundNumber1 # round of initialisation
    if (missing != 0) {
        print(c(nrow(merge1), ncol(merge1)))
        print(paste("roundMAX", roundMAX, "roundNumber", roundNumber1, 
            "--> missing", missing, "rounds"))
        sentence = paste("missing", missing, "rounds", sep="") 
        if (comment==""){
            comment = sentence
        } else{
            comment = paste(comment, "and", sentence, sep ="")
        }
    }
    merge1$comp1=(merge1$pushByzN)*100
    merge2$comp1=(merge2$pushByzN)*100
    merge3$comp1=(merge3$pushByzN)*100

    merge1$comp2=(merge1$pullByzN)*100
    merge2$comp2=(merge2$pullByzN)*100
    merge3$comp2=(merge3$pullByzN)*100

    merge1$comp3=(merge1$sampByzN)*100
    merge2$comp3=(merge2$sampByzN)*100
    merge3$comp3=(merge3$sampByzN)*100

    brahms$comp1=(brahms$pushByzN)*100
    aupe$comp1=(aupe$pushByzN)*100
    merge$comp1=(merge$pushByzN)*100

    brahms$comp2=(brahms$pullByzN)*100
    aupe$comp2=(aupe$pullByzN)*100
    merge$comp2=(merge$pullByzN)*100

    brahms$comp3=(brahms$sampByzN)*100
    aupe$comp3=(aupe$sampByzN)*100
    merge$comp3=(merge$sampByzN)*100

    title="Aupe Merge view part studying"
    title=paste(title, #"\n Byzantine proportion inside parts of the view over Time \n", 
        "f=", f*100,"% N=", N, " v=s=", v, " F=10 \n rounds=", roundNumber1)
    
    resilience1=c(tail(merge1, 1)$comp1, tail(merge1, 1)$comp2, tail(merge1, 1)$comp3)
    resilience2=c(tail(merge2, 1)$comp1, tail(merge2, 1)$comp2, tail(merge2, 1)$comp3)
    resilience3=c(tail(merge3, 1)$comp1, tail(merge3, 1)$comp2, tail(merge3, 1)$comp3)
    
    print(paste("resilience1",resilience1, "vs resilience2", resilience2, 
    "and resilience3", resilience3))
    
    resilience11=c(tail(brahms, 1)$comp1, tail(brahms, 1)$comp2, tail(brahms, 1)$comp3)
    resilience22=c(tail(aupe, 1)$comp1, tail(aupe, 1)$comp2, tail(aupe, 1)$comp3)
    resilience33=c(tail(merge, 1)$comp1, tail(merge, 1)$comp2, tail(merge, 1)$comp3)
    
    #PLOTS
    print(partview_plot(brahms, aupe, merge, merge1,merge2,merge3, f*100))

    if (path == PVIEW){
        ttc1 <- detect_first_convergence_index(merge1$comp, f, roundNumber1)
        ttc2 <- detect_first_convergence_index(merge2$comp, f, roundNumber2)
        ttc3 <- detect_first_convergence_index(merge3$comp, f, roundNumber3)
        ttc11 <- detect_first_convergence_index(brahms$comp, f, roundNumber11)
        ttc22 <- detect_first_convergence_index(aupe$comp, f, roundNumber22)
        ttc33 <- detect_first_convergence_index(merge$comp, f, roundNumber33)
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
        
        filename = paste(new, "/","dsnT", path,  sep="")
        
        part <- c("pushPart", "pullPart", "sampPart")
        write_results(filename, expe, f, paste("Aupe(t=",t1,"%)", sep = ""), rho, resilience1, part, sm,
            ttc1, roundNumber1, comment, path)
        write_results(filename, expe, f, paste("Aupe(t=",t2,"%)", sep = ""), rho, resilience2, part, sm,
            ttc2, roundNumber2, comment, path)
        write_results(filename, expe, f, paste("Aupe(t=",t3,"%)", sep = ""), rho, resilience3, part, sm,
            ttc3, roundNumber3, comment, path)
        
        write_results(filename, expe, f, "Brahms", rho, resilience11, part, sm,
            ttc11, roundNumber11, comment, path)
        write_results(filename, expe, f, "Aupe-simple", rho, resilience22, part, sm,
            ttc22, roundNumber22, comment, path)
        write_results(filename, expe, f, "Aupe-oracle", rho, resilience33, part, sm,
           ttc33, roundNumber33, comment, path)
    }
}
