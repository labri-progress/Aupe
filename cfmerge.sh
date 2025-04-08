trust="${1:-1000}" # 100 1000 2000 3000

run="${2:-0}"
if [ $run -eq 0 ]; then
    extension=""
else
    extension=""$run
fi

N=10000
sup=10
echo $trust

cargo run -- -T 200 -n $N aupe -G samples -f 10 -t 1000 -v 160 -u 160 -m 100 -n $N -x $trust -p $sup > a1$extension-$trust
cargo run -- -T 200 -n $N aupe -G samples -f 10 -t 2000 -v 160 -u 160 -m 100 -n $N -x $trust -p $sup > a2$extension-$trust
cargo run -- -T 200 -n $N aupe -G samples -f 10 -t 3000 -v 160 -u 160 -m 100 -n $N -x $trust -p $sup > a3$extension-$trust