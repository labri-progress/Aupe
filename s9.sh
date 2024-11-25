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

batch_max="${1:-5}"
thrshold="${2:-0}"
limit="${3:-10000}"
k="${4:-544}"
s="${5:-10}"
sup=10 #"${3:-30}"

round=200
force=10
N=10000

v=160

sm=100

echo $N $v $sm $sup $round CMS $s $k
echo "DATE: $(date)" 
echo "$PWD : ; DATE: $(date)" > nohup.out
expe=0
count=0

for strat in 0 1 2 #trusted
do   
    for f in 0.08 0.10 0.20 0.24 0.30 0.40 0.50
    do  
        for a in 1
        do    
            
            if (( expe >= thrshold && expe < limit ))
            then
                echo "$PWD"
                #nohup ./bin.sh 
                nohup ./cms.sh $expe $N $v $f $force $sm $round $strat $sup $k $s &

                if [ $? -eq 0 ]; then
                    echo "Expe $expe succeeded"
                    let count=count+1
                else
                    echo "Expe failed"
                fi
            fi
            
            result=$(($count % $batch_max)) 
            if (( result == 0 ))
            then
                count=0
                wait
            fi
            let expe=expe+1 
        done
    done
done

echo "*****************END($expe)*****************"