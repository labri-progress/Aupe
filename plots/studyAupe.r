CIN     = "compoIN.txt"
COUT    = "compoOUT.txt"
CVIEW   = "compoVIEW.txt"
COV     = "coverage.txt"
INDEG   = "indegree.txt"
OUTDEG  = "outdegree.txt"

source("compute.r")
source("view.r")
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

    strat1="brahms"
    strat2="aupe"
    strat3="aupe-merge"
    brahmspath = paste(filepath,"/", strat1,"/text",f*100, sep="")
    aupepath = paste(filepath,"/", strat2,"/text",f*100, sep="")
    mergepath = paste(filepath,"/", strat3,"/text",f*100, sep="")
    print(brahmspath)
    print(aupepath)
    print(mergepath)

    brahms <- read.table(brahmspath, header = TRUE)
    roundNumber1 <- nrow(brahms)
    aupe <- read.table(aupepath, header = TRUE)
    roundNumber2 <- nrow(aupe)
    merge <- read.table(mergepath, header = TRUE)
    roundNumber3 <- nrow(merge)
    print(paste("roundNumber1",roundNumber1, "vs roundNumber2", roundNumber2,
    "and roundNumber3", roundNumber3))
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
    merge$comp1=(merge$pushByzN)*100
    brahms$comp2=(brahms$pullByzN)*100
    aupe$comp2=(aupe$pullByzN)*100
    merge$comp2=(merge$pushByzN)*100
    brahms$comp3=(brahms$sampByzN)*100
    aupe$comp3=(aupe$sampByzN)*100
    merge$comp3=(merge$sampByzN)*100
    title="Aupe Brahms view part studying"
    title=paste(title, #"\n Byzantine proportion inside parts of the view over Time \n", 
        "f=", f*100,"% N=", N, " v=s=", v, " F=10 \n rounds=", roundNumber1)
    
    resilience1=c(tail(brahms, 1)$comp1, tail(brahms, 1)$comp2, tail(brahms, 1)$comp3)
    resilience2=c(tail(aupe, 1)$comp1, tail(aupe, 1)$comp2, tail(aupe, 1)$comp3)
    resilience3=c(tail(merge, 1)$comp1, tail(merge, 1)$comp2, tail(merge, 1)$comp3)
    
    print(paste("resilience1",resilience1, "vs resilience2", resilience2, 
    "and resilience3", resilience3))
    
    #PLOTS
    #print(partview_plot(brahms,aupe,merge, f*100))
    print("SECOND PLOT")
    print(dim(brahms))
    print(colnames(brahms))
    print(view_plot(brahms,aupe,merge, f*100, v))

    if (path == PVIEW){
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
        
        filename = paste(new, "/","dsn", path,  sep="")
        
        part <- c("pushPart", "pullPart", "sampPart")
        write_results(filename, expe, f, strat1, rho, resilience1, part, sm,
            ttc0, roundNumber1, comment, path)
        write_results(filename, expe, f, strat2, rho, resilience2, part, sm,
            ttc1, roundNumber2, comment, path)
        write_results(filename, expe, f, strat3, rho, resilience3, part, sm,
            ttc1, roundNumber3, comment, path)
    }
}
