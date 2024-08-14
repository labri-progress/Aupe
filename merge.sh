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
k="${8:-0}" 
r="${9:-1}" 
sup="${10:-30}"
stratLitt="aupe-merge-sup"$sup

if [ $strat -eq 0 ]; then
    t=0.01
elif [ $strat -eq 1 ]; then
    t=0.05
elif [ $strat -eq 2 ]; then
    t=0.1
elif [ $strat -eq 3 ]; then
    t=0.2
elif [ $strat -eq 4 ]; then
    t=0.3
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

T=$(echo "scale=0; 100.0 * $t / 1" | bc)
echo $folder"/text"$F"-"$T
trust=$(echo "scale=0; $N * $t / 1" | bc)
 # sup Merges
    #cargo run -- -T $roundMax -n $N aupe -O -G samples -f $force -t $byz -x $trust \

./aupefinal -T $roundMax -n $N aupe -O -G samples -f $force -t $byz -x $trust \
    -v $v -u $v -k $k -r $r  -m $sm -n $N -p $sup > $folder"/text"$F"-"$T


echo "Done------------------------"