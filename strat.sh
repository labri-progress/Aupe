#!/bin/sh

strat="${1:-0}"
N=10000
v=160
force=10
sm=100
rnd=200
r=1

f=0.26
t=0.3
k=1
sup=30
rnd=500
# ./scripts10k.sh 0 0.26 0.01 [ 1 20 500]
F=$(echo "scale=0; 100.0 * $f / 1" | bc)
echo "F="$F" rho="$k " rnd="$rnd
byz=$(echo "scale=0; $N * $f / 1" | bc)

T=$(echo "scale=0; 100.0 * $t / 1" | bc)
echo $folder"/text"$F"-"$T
trust=$(echo "scale=0; $N * $t / 1" | bc)

strat="${1:-0}"

if [ $strat -eq 0 ]; then
    nohup ./aupeTN -T $rnd -n $N aupe -O -G samples -f $force -t $byz -x $trust \
        -v 160 -u 160 -k $k -r $r -m $sm -n $N -p $sup > $stratLitt"/rho"$k"text"$F"-"$T &
elif [ $strat -eq 1 ]; then
    nohup ./aupey -T $rnd -n $N aupe -O -G samples -f $force -t $byz -x $trust \
            -v 160 -u 160 -k $k -r $r -m $sm -n $N -p $sup > $stratLitt"/rho"$k"text"$F"-"$T"RPLY" &
elif [ $strat -eq 2 ]; then
    nohup ./aupeRand -T $rnd -n $N aupe -O -G samples -f $force -t $byz -x $trust \
            -v 160 -u 160 -k $k -r $r -m $sm -n $N -p $sup > $stratLitt"/rho"$k"text"$F"-"$T"Rand" &
elif [ $strat -eq 3 ]; then
    nohup ./aupeyYRND -T $rnd -n $N aupe -O -G samples -f $force -t $byz -x $trust \
            -v 160 -u 160 -k $k -r $r -m $sm -n $N -p $sup > $stratLitt"/rho"$k"text"$F"-"$T"YRND" &
fi