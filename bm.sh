run="${1:-0}"
if [ $run -eq 0 ]; then
    extension=""
else
    extension=""$run
fi

space="${2:-6}"

N=10000

# cargo run -- -T 200 -n 1000 bm -G samples -f 10 -t 100 -v 20 -u 20 -m 100 -n 1000 -y 6
for strat in "kvs" "bm" "cf"
do
    cargo run -- -T 200 -n $N $strat -G samples -f 10 -t 3000 -v 160 -u 160 -m 100 -n $N -d 12 > $strat"3"$extension
    cargo run -- -T 200 -n $N $strat -G samples -f 10 -t 2000 -v 160 -u 160 -m 100 -n $N -d 12 > $strat"2"$extension
    cargo run -- -T 200 -n $N $strat -G samples -f 10 -t 1000 -v 160 -u 160 -m 100 -n $N -d 12 > $strat"1"$extension
done
