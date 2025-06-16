run="${1:-0}"
if [ $run -eq 0 ]; then
    extension=""
else
    extension=""$run
fi

space="${2:-6}"

N=50000

# cargo run -- -T 200 -n 1000 bm -G samples -f 10 -t 100 -v 20 -u 20 -m 100 -n 1000 -y 6
for strat in "kvs" "bm" "cf"
do
    cargo run -- -T 200 -n $N $strat -G samples -f 10 -t 15000 -v 160 -u 160 -m 100 -n $N -y $space > $strat"3"$extension
    cargo run -- -T 200 -n $N $strat -G samples -f 10 -t 10000 -v 160 -u 160 -m 100 -n $N -y $space > $strat"2"$extension
    cargo run -- -T 200 -n $N $strat -G samples -f 10 -t 5000 -v 160 -u 160 -m 100 -n $N -y $space > $strat"1"$extension
done
