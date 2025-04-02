mkdir brahms1000
cargo run -- -T 200 -n 10000 brahms -G samples -f 10 -t 1000 -v 160 -u 160 -k 0 -r 1 > b1
mkdir brahms2000
cargo run -- -T 200 -n 10000 brahms -G samples -f 10 -t 2000 -v 160 -u 160 -k 0 -r 1 > b2
mkdir brahms3000
cargo run -- -T 200 -n 10000 brahms -G samples -f 10 -t 3000 -v 160 -u 160 -k 0 -r 1 > b3