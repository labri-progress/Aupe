#!/bin/sh

simu=N="${1:-0}"
echo "received instruction for " $simu

N=10000
v=160
force=10
sm=100
roundMax=200

mkdir $strat
if [[ "$strat" == "global" ]];
    # f=22% rho=1
    cargo run -- -T 400 -n 10000 aupe -L -G samples -f $force -t 2200 \
        -v 160 -u 160 -k 1 -r 1 > $strat"/rho0text22"
elif [[ "$strat" == "merge" ]]; then
    # f=22% rho=1
    cargo run -- -T 400 -n 10000 aupe -O -G samples -f $force -t 2200 \
        -v 160 -u 160 -k 1 -r 1 > $strat"/rho0text22"
fi
