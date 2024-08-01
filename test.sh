#!/bin/bash

exeorplot="${1:-0}"
whichN="${2:-2}"
strat="${3:-0}"

gamma=0.3
sm=100
force=10
k=0
r=1
rnd=200

if [[ $whichN -eq 0 ]]
then
    expe=0
    N=10 # 100
    v=5 #20 # 160
    rnd=10
    f=0.3
    sm=10
fi
if [[ $whichN -eq 1 ]]
then
    expe=21
    N=1000 # 100
    v=100 # 160
    rnd=20
    f=0.2
fi
if [[ $whichN -eq 2 ]]
then
    expe=30
    N=10000
    v=160
    rnd=200
    f=0.2
fi 

if [ $strat -eq 0 ]; then
    stratLitt="aupe-merge"
elif [ $strat -eq 1 ]; then
    stratLitt="aupe-global"
elif [ $strat -eq 2 ]; then
    stratLitt="aupe"
elif [ $strat -eq 3 ]; then
    stratLitt="basalt-simple"
elif [ $strat -eq 4 ]; then
    stratLitt="brahms"
fi

rho=$(echo "scale=0; $k / $r / 1" | bc)

if [[ $exeorplot -eq 0 ]]
then 
    mkdir analysis
    mkdir "./analysis/rho"$rho
    mkdir "./analysis/rho"$rho"/"$N
    mkdir "./analysis/rho"$rho"/"$N"/"$stratLitt
    folder="./analysis/rho"$rho"/"$N"/"$stratLitt"/expe"$expe
    mkdir $folder
    F=$(echo "scale=0; 100.0 * $f / 1" | bc)
    echo $folder"/text"$F
    byz=$(echo "scale=0; $N * $f / 1" | bc)
    
    if [ $strat -eq 0 ]; then
    cargo run -- -T $roundMax -n $N aupe -O -G samples -f $force -t $byz \
    -v $v -u $v -k $k -r $r  -m $sm -n $N > $folder"/text"$F
    elif [ $strat -eq 1 ]; then
    cargo run -- -T $roundMax -n $N aupe -L -G samples -f $force -t $byz \
    -v $v -u $v -k $k -r $r  -m $sm -n $N > $folder"/text"$F
    elif [ $strat -eq 2 ]; then
    cargo run -- -T $roundMax -n $N aupe -G samples -f $force -t $byz \
    -v $v -u $v -k $k -r $r -m $sm -n $N > $folder"/text"$F 
    elif [ $strat -eq 3 ]; then 
    cargo run -- -T $roundMax -n $N basalt-simple -G -f $force -t $byz \
    -v $v -i 50 -k $k -r $r > $folder"/text"$F
    elif [ $strat -eq 4 ]; then 
    cargo run -- -T $roundMax -n $N brahms -G samples -f $force -t $byz \
    -v $v -u $v -k $k -r $r > $folder"/text"$F
    fi

else
    cd ./plots
    mkdir "./analysis/expe"$expe
    Rscript test.r $expe $N $v $f $sm $stratLitt $mergeLitt $gamma $rnd $t $k $s 
fi

