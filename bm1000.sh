#./bm.sh bm 1

#ratio="${1:-10}"

strat="${1:-bm}"

trusty="${2:-100}"

ratio=10

N=1000 # 10000
v=16 # 160
round=200
m=10
mkdir analysis
# cargo run -- -T 200 -n 10000 bm -G samples -f 10 -t 1000 -v 160 -u 160 -m 100 -n 10000 -y 10

# cargo run -- -T 200 -n 1000 bm -G samples -f 10 -t 100 -v 20 -u 20 -m 100 -n 1000 -y 1

# cargo run -- -T 2000 -n 10000 bm -G samples -f 10 -t 1000 -v $v -u $v -m $m -n 10000 -y 10 > "analysis/bm-10-1000-10"
# cargo run -- -T 2000 -n 10000 kvs -G samples -f 10 -t 1000 -v $v -u $v -m $m -n 10000  > "analysis/kvs-10-1000
# cargo run -- -T 2000 -n 10000 brahms -G samples -f 10 -t 1000 -v $v -u $v > "analysis/br-10-1000"
# cargo run -- -T 2000 -n 10000 basalt -G -f 10 -t 1000 -v $v -i $v -k 1 -r 1 > "analysis/bs-10-1000"

for space in 1 2 3 4 # $space #1 5 10 20 30 40
do
    for faulty in 100 200 2400 2600 280 300 #80 100 120 140 160 180 200 220 240 260 280 300 # 800 1200 1400 1600 1800 2200 2400 2600 2800 4000 # text1000 2000 3000 # 4000 5000
    do
        if [ "$strat" == "kvs" ]; then
            cargo run -- -T $round -n $N kvs -G samples -f $ratio -t $faulty -v $v -u $v -m $m -n $N > "analysis/kvs-$faulty"
        fi

        if [ "$strat" == "kvsmerge" ]; then
            cargo run -- -T $round -n $N kvs -G samples -f $ratio -t $faulty -v $v -u $v -m $m -n $N -x $trusty -p 10  > "analysis/mergekvs-$faulty-$trusty"
        fi

        if [ "$strat" == "bm" ]; then
            cargo run -- -T $round -n $N bm -G samples -f $ratio -t $faulty -v $v -u $v -m $m -n $N -y $space > "analysis/bm-$faulty-$space"
        fi

        if [ "$strat" == "merge" ]; then
            cargo run -- -T $round -n $N bm -G samples -f $ratio -t $faulty -v $v -u $v -m $m -n $N -y $space -x $trusty -p 10  > "analysis/mergebm-$faulty-$trusty-$space"
        fi

        if [ "$strat" == "basalt" ]; then
            cargo run -- -T $round -n $N basalt -G -f $ratio -t $faulty -v $v -i $v -k 1 -r 1 > "analysis/bs-$faulty"
        fi
        if [ "$strat" == "brahms" ]; then
            cargo run -- -T $round -n $N brahms -G samples -f $ratio -t $faulty -v $v -u $v > "analysis/br-$faulty"
        fi
    done
done
