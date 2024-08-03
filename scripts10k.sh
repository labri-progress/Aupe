#!/bin/sh

strat="${1:-0}"
N=10000
v=160
force=10
sm=100
rnd=200

if [ $strat -eq 0 ]; then
    stratLitt="global"
elif [ $strat -eq 1 ]; then
    stratLitt="merge"
elif [ $strat -eq 2 ]; then
    stratLitt="mergewoPond"
elif [ $strat -eq 3 ]; then
    stratLitt="mergewithPond"
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

elif [ $strat -eq 2 ]; then
    f="${2:-0}" # 0.22 0.24 0.26 0.28  
    k="${3:-0}"
    F=$(echo "scale=0; 100.0 * $f / 1" | bc)
    echo "F="$F
    byz=$(echo "scale=0; $N * $f / 1" | bc)

    rho=$(echo "scale=0; $k / $r / 1" | bc)

    echo "TotalMergewoPonderation" > $stratLitt"/log.txt"
    nohup cargo run -- -T $rnd -n $N aupe -O -G samples -f $force -t $byz \
        -v 160 -u 160 -k $k -r 1 -m $sm -n $N > $stratLitt"/rho"$rho"text"$F &

elif [ $strat -eq 3 ]; then
    f="${2:-0}" # 0.22 0.24 0.26 0.28  
    k="${3:-0}"
    F=$(echo "scale=0; 100.0 * $f / 1" | bc)
    echo "F="$F
    byz=$(echo "scale=0; $N * $f / 1" | bc)

    rho=$(echo "scale=0; $k / $r / 1" | bc)

    echo "TotalMergewithPonderation" > $stratLitt"/log.txt"
    nohup cargo run -- -T $rnd -n $N aupe -O -G samples -f $force -t $byz \
        -v 160 -u 160 -k $k -r 1 -m $sm -n $N > $stratLitt"/rho"$rho"text"$F &

fi
