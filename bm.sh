#./bm.sh bm 1

#ratio="${1:-10}"

strat="${1:-bm}"

space="${2:-10}"
ratio=10

N=10000
round=2000
mkdir analysis
# cargo run -- -T 2000 -n 10000 bm -G samples -f 10 -t 1000 -v 160 -u 160 -m 100 -n 10000 -y 10 > "analysis/bm-10-1000-10"
# cargo run -- -T 2000 -n 10000 kvs -G samples -f 10 -t 1000 -v 160 -u 160 -m 100 -n 10000  > "analysis/kvs-10-1000
# cargo run -- -T 2000 -n 10000 brahms -G samples -f 10 -t 1000 -v 160 -u 160 > "analysis/br-10-1000"
# cargo run -- -T 2000 -n 10000 basalt -G -f 10 -t 1000 -v 160 -i 160 -k 1 -r 1 > "analysis/bs-10-1000"

for space in $space #1 5 10 20 30 40
do
    for faulty in 1200 1400 2600 2800 # 800 1200 1400 1600 1800 2200 2400 2600 2800 4000 # 1000 2000 3000 # 4000 5000
    do
        if [ "$strat" == "kvs" ]; then
            cargo run -- -T $round -n $N kvs -G samples -f $ratio -t $faulty -v 160 -u 160 -m 100 -n $N > "analysis/kvs-$ratio-$faulty-$space"
        fi
        if [ "$strat" == "bm" ]; then
            cargo run -- -T $round -n $N bm -G samples -f $ratio -t $faulty -v 160 -u 160 -m 100 -n $N -y $space > "analysis/bm-$ratio-$faulty-$space"
        fi
        if [ "$strat" == "basalt" ]; then
            cargo run -- -T $round -n $N basalt -G samples -f $ratio -t $faulty -v 160 -i 160 -k 1 -r 1 > "analysis/bs-$ratio-$faulty-$space"
        fi
        if [ "$strat" == "brahms" ]; then
            cargo run -- -T $round -n $N brahms -G samples -f $ratio -t $faulty -v 160 -u 160 > "analysis/br-$ratio-$faulty-$space"
        fi
    done
done
