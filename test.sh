mkdir aupe1000
cargo run -- -T 200 -n 10000 aupe -G samples -f 10 -t 1000  -v 160 -u 160 -m 10 -n 10000  > c1
mkdir aupe2000
cargo run -- -T 200 -n 10000 aupe -G samples -f 10 -t 2000  -v 160 -u 160 -m 10 -n 10000  > c2
mkdir aupe3000
cargo run -- -T 200 -n 10000 aupe -G samples -f 10 -t 3000  -v 160 -u 160 -m 10 -n 10000  > c3