run="${1:-0}"
if [ $run -eq 0 ]; then
    extension=""
else
    extension=""$run
fi

N=10000

cargo run -- -T 200 -n $N aupe -G samples -f 10 -t 3000 -v 160 -u 160 -m 100 -n $N -x 0 -p 0 > p3$extension
cargo run -- -T 200 -n $N aupe -G samples -f 10 -t 2000 -v 160 -u 160 -m 100 -n $N -x 0 -p 0 > p2$extension
cargo run -- -T 200 -n $N aupe -G samples -f 10 -t 1000 -v 160 -u 160 -m 100 -n $N -x 0 -p 0 > p1$extension