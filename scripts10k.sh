#!/bin/sh

strat="${1:-0}"
N=10000
v=160
force=10
sm=100
rnd=200
r=1
if [ $strat -eq 0 ]; then
    stratLitt="global"
elif [ $strat -eq 1 ]; then
    stratLitt="merge100"
elif [ $strat -eq 2 ]; then
    stratLitt="mergewoPond"
elif [ $strat -eq 3 ]; then
    stratLitt="mergewithPond"
elif [ $strat -eq 4 ]; then
    stratLitt="aupewithT"
elif [ $strat -eq 5 ]; then
    stratLitt="addition"
elif [ $strat -eq 6 ]; then
    stratLitt="aupe"
elif [ $strat -eq 7 ]; then
    stratLitt="mergeT"
fi
echo "received instruction for " $stratLitt

mkdir $stratLitt
if [ $strat -eq 0 ]; then
    f="${2:-0}" #"${2:-0}" # 0.22 0.24 0.26 0.28  
    k="${3:-0}"
    rnd="${4:-600}"
    # ./scripts10k.sh 0 0.26 1
    F=$(echo "scale=0; 100.0 * $f / 1" | bc)
    echo "F="$F" rho="$k " rnd="$rnd
    byz=$(echo "scale=0; $N * $f / 1" | bc)

    echo "Globalw600rounds" > $stratLitt"/log.txt"
    nohup ./aupeglobal -T $rnd -n $N aupe -L -G samples -f $force -t $byz \
        -v 160 -u 160 -k $k -r 1 -m $sm -n $N > $stratLitt"/rho"$k"text"$F &

elif [ $strat -eq 1 ]; then
    f="${2:-0}" #"${2:-0}" # 0.22 0.24 0.26 0.28  
    k="${3:-0}"
    rnd="${4:-600}"
    # ./scripts10k.sh 1 0.26 1
    F=$(echo "scale=0; 100.0 * $f / 1" | bc)
    echo "F="$F" rho="$k " rnd="$rnd
    byz=$(echo "scale=0; $N * $f / 1" | bc)

    echo "TotalMergew600rounds" > $stratLitt"/log.txt"
    nohup ./aupewoponderation -T $rnd -n $N aupe -O -G samples -f $force -t $byz \
        -v 160 -u 160 -k $k -r 1 -m $sm -n $N > $stratLitt"/rho"$k"text"$F &

elif [ $strat -eq 2 ]; then
    f="${2:-0}" # 0.22 0.24 0.26 0.28  
    k="${3:-0}"
    # ./scripts10k.sh 2 0.22 1
    F=$(echo "scale=0; 100.0 * $f / 1" | bc)
    echo "F="$F" rho="$k " rnd="$rnd
    byz=$(echo "scale=0; $N * $f / 1" | bc)

    echo "TotalMergewoPonderation" > $stratLitt"/log.txt"
    nohup ./aupewoponderation -T $rnd -n $N aupe -O -G samples -f $force -t $byz \
        -v 160 -u 160 -k $k -r 1 -m $sm -n $N > $stratLitt"/rho"$k"text"$F &

elif [ $strat -eq 3 ]; then
    f="${2:-0}" # 0.22 0.24 0.26 0.28  
    k="${3:-0}"
    F=$(echo "scale=0; 100.0 * $f / 1" | bc)
    echo "F="$F
    byz=$(echo "scale=0; $N * $f / 1" | bc)
    # ./scripts10k.sh 3 0.22 1

    echo "TotalMergewithPonderation" > $stratLitt"/log.txt"
    nohup ./aupewithponderation -T $rnd -n $N aupe -O -G samples -f $force -t $byz \
        -v 160 -u 160 -k $k -r 1 -m $sm -n $N > $stratLitt"/rho"$k"text"$F &

elif [ $strat -eq 4 ]; then
    f="${2:-0}" # 0.22 0.24 0.26 0.28  
    t="${3:-0}"
    k="${4:-0}"
    F=$(echo "scale=0; 100.0 * $f / 1" | bc)
    echo "F="$F
    byz=$(echo "scale=0; $N * $f / 1" | bc)
    # ./scripts10k.sh 4 0.22 0.01 1

    T=$(echo "scale=0; 100.0 * $t / 1" | bc)
    echo $folder"/text"$F"-"$T
    trust=$(echo "scale=0; $N * $t / 1" | bc)

    echo "TotalMergewithT" > $stratLitt"/log.txt"
    nohup ./aupewitT -T $rnd -n $N aupe -O -G samples -f $force -t $byz -x $trust \
        -v 160 -u 160 -k $k -r 1 -m $sm -n $N > $stratLitt"/rho"$k"text"$F"-"$T &

elif [ $strat -eq 5 ]; then
    f="${2:-0}" # 0.22 0.24 0.26 0.28  
    t="${3:-0}"
    k="${4:-0}"
    F=$(echo "scale=0; 100.0 * $f / 1" | bc)
    echo "F="$F
    byz=$(echo "scale=0; $N * $f / 1" | bc)
    # ./scripts10k.sh 5 0.22 0.01 1

    T=$(echo "scale=0; 100.0 * $t / 1" | bc)
    echo $folder"/text"$F"-"$T
    trust=$(echo "scale=0; $N * $t / 1" | bc)

    echo "TotalMergewithAddition" > $stratLitt"/log.txt"
    nohup ./add -T $rnd -n $N aupe -O -G samples -f $force -t $byz -x $trust \
        -v 160 -u 160 -k $k -r 1 -m $sm -n $N > $stratLitt"/rho"$k"text"$F"-"$T &

elif [ $strat -eq 6 ]; then
    f="${2:-0}" #"${2:-0}" # 0.22 0.24 0.26 0.28  
    k="${3:-0}"
    rnd="${4:-600}"
    # ./scripts10k.sh 6 0.26 1
    F=$(echo "scale=0; 100.0 * $f / 1" | bc)
    echo "F="$F" rho="$k " rnd="$rnd
    byz=$(echo "scale=0; $N * $f / 1" | bc)

    echo "Aupe" > $stratLitt"/log.txt"
    nohup ./aupewoponderation -T $rnd -n $N aupe -G samples -f $force -t $byz \
        -v 160 -u 160 -k $k -r 1 -m $sm -n $N > $stratLitt"/rho"$k"text"$F &

elif [ $strat -eq 7 ]; then
    f="${2:-0}"
    t="${3:-0}"
    k="${4:-0}"
    rnd="${5:-600}"
    F=$(echo "scale=0; 100.0 * $f / 1" | bc)
    echo "F="$F" rho="$k " rnd="$rnd
    byz=$(echo "scale=0; $N * $f / 1" | bc)
    # ./scripts10k.sh 7 0.26 0.01 1

    T=$(echo "scale=0; 100.0 * $t / 1" | bc)
    echo $folder"/text"$F"-"$T
    trust=$(echo "scale=0; $N * $t / 1" | bc)

    echo "MergewT" > $stratLitt"/log.txt"
    nohup ./aupewitT -T $rnd -n $N aupe -O -G samples -f $force -t $byz -x $trust \
        -v 160 -u 160 -k $k -r 1 -m $sm -n $N > $stratLitt"/rho"$k"text"$F"-"$T &

fi
