strat="${1:-0}"
run="${1:-0}"
if [ $run -eq 0 ]; then
    extension=""
else
    extension=""+$run
fi

N=10000
if [ $strat -eq 0 ]; then
    mkdir aupe1000
    ./strats/aupeKVS -T 200 -n $N aupe -G samples -f 10 -t 1000 -v 160 -u 160 -m 100 -n $N  > a1$run
    mkdir aupe2000
    ./strats/aupeKVS -T 200 -n $N aupe -G samples -f 10 -t 2000 -v 160 -u 160 -m 100 -n $N  > a2$run
    mkdir aupe3000
    ./strats/aupeKVS -T 200 -n $N aupe -G samples -f 10 -t 3000 -v 160 -u 160 -m 100 -n $N  > a3$run
else
    mkdir cf1000
    ./strats/aupeCF -T 200 -n $N aupe -G samples -f 10 -t 1000 -v 160 -u 160 -m 100 -n $N  > a1$run
    mkdir cf2000
    ./strats/aupeCF -T 200 -n $N aupe -G samples -f 10 -t 2000 -v 160 -u 160 -m 100 -n $N  > a2$run
    mkdir cf3000
    ./strats/aupeCF -T 200 -n $N aupe -G samples -f 10 -t 3000 -v 160 -u 160 -m 100 -n $N  > a3$run
fi