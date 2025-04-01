mkdir log1000
cargo run -- -T 200 -n 10000 aupe -G samples -f 10 -t 1000 -x 0 -v 160 -u 160 -m 10 -n 10000 -p 0 > c1
mkdir log2000
cargo run -- -T 200 -n 10000 aupe -G samples -f 10 -t 2000 -x 0 -v 160 -u 160 -m 10 -n 10000 -p 0 > c2
mkdir log3000
cargo run -- -T 200 -n 10000 aupe -G samples -f 10 -t 3000 -x 0 -v 160 -u 160 -m 10 -n 10000 -p 0 > c3