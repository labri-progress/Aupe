#!/bin/sh

strat="${1:-0}"
N=10000
v=160
force=10
sm=100
rnd=200
r=1
if [ $strat -eq 0 ]; then
    stratLitt="basalt"
elif [ $strat -eq 1 ]; then
    stratLitt="aupe-merge"
elif [ $strat -eq 2 ]; then
    stratLitt="sample"
elif [ $strat -eq 3 ]; then
    stratLitt="rho"
elif [ $strat -eq 4 ]; then
    stratLitt="globalT"
fi
echo "received instruction for " $stratLitt

mkdir $stratLitt
if [ $strat -eq 0 ]; then
    f="${2:-0}" # 0.20 0.22 0.24 0.26 0.28 0.30
    rnd="${3:-1000}"
    k="${4:-1}"
    # ./scripts10k.sh 0 0.26
    F=$(echo "scale=0; 100.0 * $f / 1" | bc)
    echo "F="$F" rho="$k " rnd="$rnd
    byz=$(echo "scale=0; $N * $f / 1" | bc)

    echo "Basalt Rounds" > $stratLitt"/log.txt"
    nohup ./basalt-sim -T $rnd -n $N basalt-simple -G -f $force -t $byz \
        -v 160 -i 160 -k $k -r 1 > $stratLitt"/rho"$k"text"$F &

elif [ $strat -eq 1 ]; then
    f="${2:-0}" # 0.20 0.22 0.24 0.26 0.28 0.30
    t="${3:-0.01}"
    rnd="${4:-1000}"
    k="${5:-1}"
    # ./scripts10k.sh 1 0.26 0.01 
    F=$(echo "scale=0; 100.0 * $f / 1" | bc)
    echo "F="$F" rho="$k " rnd="$rnd
    byz=$(echo "scale=0; $N * $f / 1" | bc)


    T=$(echo "scale=0; 100.0 * $t / 1" | bc)
    echo $folder"/text"$F"-"$T
    trust=$(echo "scale=0; $N * $t / 1" | bc)
    
    echo "aupe-merge Rounds" > $stratLitt"/log.txt"
    nohup ./aupewitT -T $rnd -n $N aupe -O -G samples -f $force -t $byz -x $trust \
        -v 160 -u 160 -k $k -r 1 -m $sm -n $N > $stratLitt"/rho"$k"text"$F"-"$T &
  
elif [ $strat -eq 2 ]; then
    t="${2:-0.01}"
    sm="${3:-0}" # 200 500 1000
    f="${4:-0.24}"
    rnd="${5:-1000}"
    k="${6:-1}"

    # ./scripts10k.sh 2 0.01 200
    F=$(echo "scale=0; 100.0 * $f / 1" | bc)
    echo "F="$F" rho="$k " rnd="$rnd
    byz=$(echo "scale=0; $N * $f / 1" | bc)


    T=$(echo "scale=0; 100.0 * $t / 1" | bc)
    echo $folder"/text"$F"-"$T
    trust=$(echo "scale=0; $N * $t / 1" | bc)
    
    echo "sample" > $stratLitt"/log.txt"
    nohup ./aupewitT -T $rnd -n $N aupe -O -G samples -f $force -t $byz -x $trust \
        -v 160 -u 160 -k $k -r 1 -m $sm -n $N > $stratLitt"/rho"$k"text"$F"-"$T"-"$sm  &

elif [ $strat -eq 3 ]; then
    t="${2:-0.01}"
    k="${3:-1}" # 10 20 50 100
    f="${4:-0.24}"
    rnd="${5:-1000}"

    # ./scripts10k.sh 3 0.01 10
    F=$(echo "scale=0; 100.0 * $f / 1" | bc)
    echo "F="$F" rho="$k " rnd="$rnd
    byz=$(echo "scale=0; $N * $f / 1" | bc)


    T=$(echo "scale=0; 100.0 * $t / 1" | bc)
    echo $folder"/text"$F"-"$T
    trust=$(echo "scale=0; $N * $t / 1" | bc)
    
    echo "Rho" > $stratLitt"/log.txt"
    nohup ./aupewitT -T $rnd -n $N aupe -O -G samples -f $force -t $byz -x $trust \
        -v 160 -u 160 -k $k -r $k -m $sm -n $N > $stratLitt"/rho"$k"text"$F"-"$T &

elif [ $strat -eq 4 ]; then
    t="${2:-0.01}"
    f="${3:-0.24}"
    k="${4:-1}"
    rnd="${5:-1000}"
    
    # ./scripts10k.sh 4 0.01 0.22
    F=$(echo "scale=0; 100.0 * $f / 1" | bc)
    byz=$(echo "scale=0; $N * $f / 1" | bc)


    T=$(echo "scale=0; 100.0 * $t / 1" | bc)
    echo "rho"$k"Gtext"$F"-"$T
    trust=$(echo "scale=0; $N * $t / 1" | bc)
    
    echo "Rho" > $stratLitt"/log.txt"
    nohup ./aupeGT -T $rnd -n $N aupe -L -G samples -f $force -t $byz -x $trust \
        -v 160 -u 160 -k $k -r $k -m $sm -n $N > $stratLitt"/rho"$k"Gtext"$F"-"$T &

fi
