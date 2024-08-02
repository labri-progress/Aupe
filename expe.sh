#!/bin/bash

# Script to run all the experiment

# ./expe.sh 0 1 3
echo "[Experiments : $@]"

nohup echo "[Experiments : $@]"
# $1 : expe to begin with (threshold): defaut expe 0
# $2 : give the number of expe to run: default 5
# $3 : protocol strategy
# $4 : merge strategy
# $5 : Expe at wich we end (limit): default no limit
# $6 : number of rounds for all my expe: default 400

thrshold="${1:-0}"
A="${2:-1}"
limit="${3:-10000}"

batch_max=8

round=200
force=10
N=10000 #10000
v=160
sm=100
#f_values=( 0.08 0.10 ) #0.12 0.14 0.16 0.18 0.20 0.22 0.24 0.26 0.28 0.30 0.32 0.34 0.36 0.38 0.40 0.42 0.44 0.46 0.48 0.50) 

echo "DATE: $(date)" 
echo "DATE: $(date)" > nohup.out
expe=0
r=1
count=0
for strat in 0 1 2 3 4
do   
    for k in 0 1 
    do   
        for f in 0.08 0.10 0.12 0.14 0.16 0.18 0.20 0.22 0.24 0.26 0.28 0.30 0.32 0.34 0.36 0.38 0.40 0.42 0.44 0.46 0.48 0.50
        do  
            for a in 1 #$( eval echo {1..$(($A))}) # run each experiment many times
            do    
                
                if (( expe >= thrshold && expe < limit ))
                then
                    echo "Expe: $expe"
                    echo "$PWD"
                    nohup ./trusted.sh $expe $N $v $f $force $sm $round $strat $k $r &

                    if [ $? -eq 0 ]; then
                        echo "Expe succeeded"
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

done

echo "*****************END($expe)*****************"