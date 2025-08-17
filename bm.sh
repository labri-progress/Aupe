#./bm.sh 10 10

ratio="${1:-10}"

space="${2:-10}"

N=10000
round=2000
# cargo run -- -T 200 -n 1000 bm -G samples -f 10 -t 100 -v 20 -u 20 -m 100 -n 1000 -y 6
for strat in "bm" #"kvs" "bm" "cf"
do
    for space in $space #10 20 30 40
    do
        for faulty in 1000 2000 3000 # 4000 5000
        do
            cargo run -- -T $round -n $N $strat -G samples -f $ratio -t $faulty -v 160 -u 160 -m 100 -n $N -y $space > "analysis/"$strat"-"$ratio"-"$faulty"-"$space
            
        done
    done
done
