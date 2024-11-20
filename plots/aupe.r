CIN     = "compoIN.txt"
COUT    = "compoOUT.txt"
CVIEW   = "compoVIEW.txt"
COV     = "coverage.txt"
INDEG   = "indegree.txt"
OUTDEG  = "outdegree.txt"

source("compute.r")

write_results <- function(filename, expe, f, t, strat, dim,
    resilience, sm, ttC, roundNumber, comment) {
    file.info(filename)$size
    if (!file.exists(filename)) {
       head <- "Expe     faulty     trusty     Strat     dim     resilience     ttC     sm     round     comment"
        write(head, append=TRUE, file = filename)
    }
    separator = "        "
    sol = paste(expe, f*100, t*100, strat, dim, resilience, ttC, sm, roundNumber, comment, sep = separator)
    write(sol, append=TRUE, file = filename)
}
cms <- function(args, path, topic) {  
    # 0. Data      
    #print(path)
    N = as.numeric(args[1])
    v = as.numeric(args[2])
    f = as.numeric(args[3])
    t = as.numeric(args[4])
    sm = as.numeric(args[5])
    strat1name = args[6]
    strat2name = args[7]
    roundMAX = as.double(args[8])
    folder = args[9]
    k=as.numeric(args[10])
    s=as.numeric(args[11])
    m=as.numeric(args[12])

    print(args)
    # 1. Plots
    
    name = sub(pattern = "(.*)\\..*$", replacement = "\\1", basename(path))
    print(name)
    ymax = 100
    
    filepath = paste("/home/amukam/thss/simulation/Aupe/analysis/", N, sep="")
    strat1path = paste(filepath,"/", strat1name,"/text",f*100, sep="")
    strat2path = paste(filepath,"/", strat2name,"/text",f*100, sep="")
    if (t!=0){
        strat1path = paste(strat1path,"-",t*100, sep="")
        strat2path = paste(strat2path,"-",t*100, sep="")
    }
    print(strat1path)
    print(strat2path)
    
    strat1 <- read.table(strat1path, header = TRUE)
    roundNumber1 <- nrow(strat1)
    strat2 <- read.table(strat2path, header = TRUE)
    roundNumber2 <- nrow(strat2)
    print(paste("roundNumber1",roundNumber1, "vs roundNumber2", roundNumber2))
    comment="" # for logging
    missing = roundMAX +1 - roundNumber1 # round of initialisation
    if (missing != 0) {
        print(c(nrow(strat1), ncol(strat1)))
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
        strat1$comp=(strat1$avgByzN/v)*100
        strat2$comp=(strat2$avgByzN/v)*100
        title=paste("Byzantine proportion inside view over Time f=", 
            f*100,"%","  t=", t*100,"%  
            N=", N, " v=s=", v, " m=", m, " F=10 rounds=", roundNumber1, sep="")
    }else if(path == SAMPLE){
        strat1$comp=(strat1$avgByzSamp/v)*100
        strat2$comp=(strat2$avgByzSamp/v)*100
        title="Byzantine proportion inside sample over Time"
    }else {
        title="Evolution of coverage over Time"
    }
    
    resilience1=tail(strat1, 1)$comp
    resilience2=tail(strat2, 1)$comp
    print(paste("resilience1",resilience1, "vs resilience2", resilience2))
    
    #print(strat1$comp)
    plot(strat1$comp, main=title, col="red", type = "l", lwd = 2, ylim=c(0,100), xlab="Rounds", ylab="Resilience")
    lines(strat2$comp, col="blue", type = "l", lwd = 2)
    
    grid(nx = NA, ny = NULL, col = "lightgray", lty = "dotted")
    axis(2, at = seq(0, 100, by = 10), labels = seq(0, 100, by = 10)) 
    abline(h = f*100, col = "yellow", lty = 2, lwd = 2)
    labels = c(paste(strat1name, "(",k, ",", s, ")", sep=""), 
        strat2name)
    colors = c("red", "blue")
    locator(1) 
    legend("topright", legend = labels, box.col = "grey",col = colors, lwd = 2, xpd = TRUE)
    

    # Detect the first index of convergence
    if (path == CVIEW){
        ttc0 <- detect_first_convergence_index(strat1$comp, f, roundNumber1)
        ttc1 <- detect_first_convergence_index(strat2$comp, f, roundNumber2)
    
        # 2. Logs
        
        if (comment==""){
        comment="RAS"
        }
        param = paste("m=", m, sep="")
        system = paste("N=", N, " v=",  v, sep="")
        #study = paste("strat=", strat, sep="")
        mainDir = "../results/"
        dir.create(file.path(mainDir, param)) # check folder existence
        new = paste(mainDir, param, sep="")
        dir.create(file.path(new, system)) 
        new = paste(new, "/", system, sep="")
        #dir.create(file.path(new, study))
        print(paste("name", name))
        filename = paste(new, "/", name,  sep="")
        
        print(filename)
        dim = paste("cms(", s, ",", k, ")", sep="")
        write_results(filename, expe, f, t, strat1name, dim, resilience1, sm,
            ttc0, roundNumber1, comment)
        
        write_results(filename, expe, f, t, strat2name, "omn", resilience2, sm,
            ttc1, roundNumber2, comment)
        
    }
}
