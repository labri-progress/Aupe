#!/bin/sh

strat="${1:-0}"


N=10000
v=160
force=10
sm=100
roundMax=200

if [ $strat -eq 0 ]; then
    stratLitt="global"
elif [ $strat -eq 1 ]; then
    stratLitt="merge"
elif [ $strat -eq 2 ]; then
    stratLitt="aupe"
elif [ $strat -eq 3 ]; then
    stratLitt="basalt-simple"
elif [ $strat -eq 4 ]; then
    stratLitt="brahms"
fi
echo "received instruction for " $stratLitt

mkdir $stratLitt
if [ $strat -eq 0 ]; then
    # f=22% rho=1
    echo "Globalw400rounds" > $stratLitt"/log.txt"
    nohup cargo run -- -T 400 -n $N aupe -L -G samples -f $force -t 2200 \
        -v 160 -u 160 -k 1 -r 1 -m $sm -n $N > $stratLitt"/rho1text22" &
elif [ $strat -eq 1 ]; then
    # f=22% rho=1
    echo "TotalMergew400rounds" > $stratLitt"/log.txt"
    nohup cargo run -- -T 400 -n $N aupe -O -G samples -f $force -t 2200 \
        -v 160 -u 160 -k 1 -r 1 -m $sm -n $N > $stratLitt"/rho1text22" &
fi
