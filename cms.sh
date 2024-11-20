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

# ./cms.sh 0 1000 20 0.3 10 100 200 2 1 272 10 &
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
sup="${8:-30}"
k="${9:-50}" 
s="${10:-10}" 
stratLitt="cms-merge-sup"$sup

if [ $strat -eq 0 ]; then
    t=0
elif [ $strat -eq 1 ]; then
    t=0.01
elif [ $strat -eq 2 ]; then
    t=0.1
elif [ $strat -eq 3 ]; then
    t=0.2
elif [ $strat -eq 4 ]; then
    t=0.3
fi
mkdir analysis
mkdir "./analysis/"
mkdir "./analysis/"$N
mkdir "./analysis/"$N"/"$stratLitt
folder="./analysis/"$N"/"$stratLitt #"/expe"$expe
#mkdir $folder
F=$(echo "scale=0; 100.0 * $f / 1" | bc)
echo $folder"/text"$F
byz=$(echo "scale=0; $N * $f / 1" | bc)

T=$(echo "scale=0; 100.0 * $t / 1" | bc)
echo $folder"/text"$F"-"$T
trust=$(echo "scale=0; $N * $t / 1" | bc)
if [ $strat -eq 0 ]; then
    cargo run -- -T $roundMax -n $N cms -G samples -f $force -t $byz \
    -v $v -u $v -m $sm -n $N -d $s -w $k > $folder"/text"$F
else
    cargo run -- -T $roundMax -n $N cms -G samples -f $force -t $byz -v $v \
    -u $v -m $sm -n $N -d $s -w $k -x $trust -p $sup > $folder"/text"$F"-"$T
fi

echo "Done------------------------"