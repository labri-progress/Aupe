#!/bin/bash

# $1 : expe number
# $2 : peers
# $3 : viewsize
# $4 : byzpercent
# $5 : trustpercent
# $6 : sample memory
# $7 : number of rounds
# $8 : debiasing strategy
# $9 : merge strategy
# $10 : gamma = beta = (1 - beta)/2
# $11 : share knowledge
# $12 : replacement count
# $13 : replacement frequency
expe="${1:-0}"
shift
echo "Experiment ($expe) with params $@" 

N="${1:-10000}"
v="${2:-160}"
f="${3:-0.10}"
force="${4:-10}"
sm="${5:-100}"
roundMax="${6:-200}"
strat="${7:-1}"
k="${8:-0}" #number_of_partitions
r="${9:-1}" #number_of_hash_functions
#t="${5:-0.01}"
#mergestrat="${9:-0}"
#gamma="${10:-0.2}"

if [ $strat -eq 1 ]; then
    stratLitt="aupe-merge"
elif [ $strat -eq 2 ]; then
    stratLitt="aupe"
else
    stratLitt="basalt-simple"
fi
rho=$(echo "scale=0; $k / $r / 1" | bc)
mkdir analysis
mkdir "./analysis/rho"$rho
mkdir "./analysis/rho"$rho"/"$N
mkdir "./analysis/rho"$rho"/"$N"/"$stratLitt
folder="./analysis/rho"$rho"/"$N"/"$stratLitt"/expe"$expe
mkdir $folder
F=$(echo "scale=0; 100.0 * $f / 1" | bc)
echo $folder"/text"$F
byz=$(echo "scale=0; $N * $f / 1" | bc)
if [ $strat -eq 1 ]; then
   #cargo run -- -T $roundMax -n $N brahms -G -f $force -t $byz \
   #-v $v -u $v -k $k -r $r > $folder"/text"$F
   cargo run -- -T $roundMax -n $N aupe -O -G -f $force -t $byz \
   -v $v -u $v -k $k -r $r  -m $sm -n $N > $folder"/text"$F
elif [ $strat -eq 2 ]; then
   cargo run -- -T $roundMax -n $N aupe -G -f $force -t $byz \
   -v $v -u $v -k $k -r $r -m $sm -n $N > $folder"/text"$F 
else 
   cargo run -- -T $roundMax -n $N basalt-simple -G -f $force -t $byz \
   -v $v -i 50 -k $k -r $r > $folder"/text"$F
fi
echo "Done------------------------"