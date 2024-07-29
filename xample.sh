#!/bin/sh

aco "Try Basalt"
cargo run -- -T 200 -n 1000 basalt -G -H -f 10 -t 300 -v 50 -i 50 -k 10 -r 10 

echo "Try Brahms"
cargo run -- -T 200 -n 1000 brahms -G samples -f 10 -t 300 -v 50 -u 50 -k 10 -r 10 

echo "Try Aupe"
cargo run -- -T 200 -n 1000 aupe -G samples -f 10 -t 300 -v 50 -u 50 -k 10 -r 10 -m 100
cargo run -- -T 10 -n 10 aupe -G samples -f 10 -t 3 -v 5 -u 5 -k 1 -r 1 -m 10 -n 10
