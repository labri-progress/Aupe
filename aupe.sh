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

thrshold="${1:-0}"
limit="${2:-10000}"
sup=10 #"${3:-30}"

batch_max=5

round=200
force=10
N=10000

v=160

sm=100
#f_values=( 0.08 0.10 ) #0.12 0.14 0.16 0.18 0.20 0.22 0.24 0.26 0.28 0.30 0.32 0.34 0.36 0.38 0.40 0.42 0.44 0.46 0.48 0.50) 
echo $N $v $sm $sup $round $s $k
echo "DATE: $(date)" 
echo "DATE: $(date)" > nohup.out
expe=0
count=0

for strat in 0 1 2 #trusted
do   
    for f in 0.08 0.10 0.20 0.24 0.30 0.40 0.50
    do  
        for a in 1 #$( eval echo {1..$(($A))}) # run each experiment many times
        do    
            
            if (( expe >= thrshold && expe < limit ))
            then
                echo "$PWD"
                echo ./merge.sh $expe $N $v $f $force $sm $round $strat $sup >> log.txt
                nohup ./merge.sh $expe $N $v $f $force $sm $round $strat $sup &

                if [ $? -eq 0 ]; then
                    echo "Expe $expe succeeded"
                    let count=count+1
                else
                    echo "Expe failed"
                fi
            fi
            #echo "*****************NEXT*****************"
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