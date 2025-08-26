#./bm.sh 10 10

ratio="${1:-10}"

space="${2:-10}"

N=10000
round=2000
mkdir analysis
# cargo run -- -T 2000 -n 10000 bm -G samples -f 10 -t 1000 -v 160 -u 160 -m 100 -n 10000 -y 10 > "analysis/bm-10-1000-10"
# cargo run -- -T 2000 -n 10000 kvs -G samples -f 10 -t 1000 -v 160 -u 160 -m 100 -n 10000  > "analysis/kvs-10-1000
# cargo run -- -T 2000 -n 10000 brahms -G samples -f 10 -t 1000 -v 160 -u 160 
# cargo run -- -T 2000 -n 10000 basalt -G -f 10 -t 3000 -v 160 -i 160 

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
