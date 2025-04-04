run="${1:-0}"
if [ $run -eq 0 ]; then
    extension=""
else
    extension=""+$run
fi

N=10000
cargo run -- -T 200 -n $N aupe -G samples -f 10 -t 1000 -v 160 -u 160 -m 100 -n $N  > a1$extension
cargo run -- -T 200 -n $N aupe -G samples -f 10 -t 2000 -v 160 -u 160 -m 100 -n $N  > a2$extension
cargo run -- -T 200 -n $N aupe -G samples -f 10 -t 3000 -v 160 -u 160 -m 100 -n $N  > a3$extension