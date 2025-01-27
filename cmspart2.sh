#!/bin/bash

# Script to run all the experiment

# ./xexpe.sh 0 10 1
echo "[Experiments : $@]"

nohup echo "[Experiments : $@]"
# $1 : expe to begin with (threshold): defaut expe 0
# $2 : give the number of expe to run: default 5
# $3 : protocol strategy
# $4 : merge strategy
# $5 : Expe at wich we end (limit): default no limit
# $6 : number of rounds for all my expe: default 400

xpe="${1:-0}"
k="${2:-1000}"
s="${3:-10}"
sup=10 #"${3:-30}"

round=200
force=10
N=10000

v=160

sm=100

r=3

echo $N $v $sm $sup $round CMS $s $k
echo "DATE: $(date)" 
echo "$PWD : ; DATE: $(date)" > nohup.out
expe=0
count=0

for strat in 0 1 2 #trusted
do   
    for f in 0.12 0.14 0.16 0.18 0.22 0.26 0.28 0.32 0.34 0.36 0.38 0.42 0.44 0.46 0.48
    do  
        for a in "cms"
        do    
            
            if (( expe == xpe ))
            then
                echo "$PWD"
                #nohup ./bin.sh 
                nohup ./cms.sh $expe $N $v $f $force $sm $round $strat $sup $k $s $a $r &

                if [ $? -eq 0 ]; then
                    echo "Expe $expe succeeded"
                    let count=count+1
                else
                    echo "Expe failed"
                fi
            fi
            
            let expe=expe+1 
        done
    done
done

echo "*****************END($expe)*****************"