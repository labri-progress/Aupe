#!/bin/sh

aco "Try Basalt"
cargo run -- -T 200 -n 1000 basalt-simple -G -f 10 -t 300 -v 100 -i 100 -k 1 -r 1

echo "Try Brahms"
cargo run -- -T 200 -n 1000 brahms -G samples -f 10 -t 300 -v 100 -u 100 -k 1 -r 1

echo "Try Aupe"
cargo run -- -T 200 -n 1000 aupe -G samples -f 10 -t 200 -v 100 -u 100 -k 1 -r 1 -m 100 -n 1000
cargo run -- -T 10 -n 10 aupe -G samples -f 10 -t 3 -v 5 -u 5 -k 1 -r 1 -m 10 -n 10
cargo run -- -T 200 -n 10000 aupe -O -G samples -f 10 -t 2000 -v 160 -u 160 -k 1 -r 1 -m 100 -n 10000 # aupe-merge
cargo run -- -T 200 -n 10000 aupe -L -G samples -f 10 -t 2000 -v 160 -u 160 -k 1 -r 1 -m 100 -n 10000 # aupe-global
