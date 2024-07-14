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

round=200
force=10
N=10000
v=160
sm=100
#f_values=( 0.08 0.10 ) #0.12 0.14 0.16 0.18 0.20 0.22 0.24 0.26 0.28 0.30 0.32 0.34 0.36 0.38 0.40 0.42 0.44 0.46 0.48 0.50) 
cd Aupe
echo "DATE: $(date)" 
echo "DATE: $(date)" > nohup.out
expe=0
r=1
for strat in 1 2 3
do   
    for k in 0 1 
    do   
        for f in 0.08 0.10 0.12 0.14 0.16 0.18 0.20 0.22 0.24 0.26 0.28 0.30 0.32 0.34 0.36 0.38 0.40 0.42 0.44 0.46 0.48 0.50
 
        do    
            if [ $expe -gt $limit ]
            then
                echo "EXPE $expe!"
                break
            fi
            for a in 1 #$( eval echo {1..$(($A))}) # run each experiment many times
            do    
                if [ $expe -lt $thrshold ]
                then
                    echo "EXPE $expe!"
                    let expe=expe+1
                    continue
                else
                    exit 0
                fi
                #echo $expe $N $v $f $force $sm $round $strat $k $r
                echo "$PWD"
                
                nohup ./trusted.sh $expe $N $v $f $force $sm $round $strat $k $r &

                if [ $? -eq 0 ]; then
                    echo "Expe succeeded"
                else
                    echo "Expe failed"
                fi
                echo "*****************NEXT*****************"
                let expe=expe+1
            done
        done
    done

done

echo "*****************END($expe)*****************"