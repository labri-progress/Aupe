#!/bin/sh

strat="${1:-0}"
N=10000
v=160
force=10
sm=100
rnd=200
r=1
if [ $strat -eq 0 ]; then
    stratLitt="TNcontact"
fi
echo "received instruction for " $stratLitt

mkdir $stratLitt
if [ $strat -eq 0 ]; then
    f="${2:-0}" # 0.20 0.22 0.24 0.26 0.28 0.30
    t="${3:-0.01}"
    rnd="${4:-1000}"
    k="${5:-1}"
    # ./scripts10k.sh 0 0.26 0.01 [ 1000 1 ]
    F=$(echo "scale=0; 100.0 * $f / 1" | bc)
    echo "F="$F" rho="$k " rnd="$rnd
    byz=$(echo "scale=0; $N * $f / 1" | bc)


    T=$(echo "scale=0; 100.0 * $t / 1" | bc)
    echo $folder"/text"$F"-"$T
    trust=$(echo "scale=0; $N * $t / 1" | bc)
    
    echo $stratLitt > $stratLitt"/log.txt"
    nohup ./aupeTN -T $rnd -n $N aupe -O -G samples -f $force -t $byz -x $trust \
        -v 160 -u 160 -k $k -r $r -m $sm -n $N > $stratLitt"/rho"$k"text"$F"-"$T &
fi
