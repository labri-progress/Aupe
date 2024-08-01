#!/bin/sh

cargo run -- -T 200 -n 1000 brahms -G samples -f 10 -t 80 -v 100 -u 100 -k 0 -r 1 > text8 &
cargo run -- -T 200 -n 1000 brahms -G samples -f 10 -t 100 -v 100 -u 100 -k 0 -r 1 > text10 &
cargo run -- -T 200 -n 1000 brahms -G samples -f 10 -t 140 -v 100 -u 100 -k 0 -r 1 > text14 &
cargo run -- -T 200 -n 1000 brahms -G samples -f 10 -t 180 -v 100 -u 100 -k 0 -r 1 > text18 &
cargo run -- -T 200 -n 1000 brahms -G samples -f 10 -t 200 -v 100 -u 100 -k 0 -r 1 > text20 &
cargo run -- -T 200 -n 1000 brahms -G samples -f 10 -t 240 -v 100 -u 100 -k 0 -r 1 > text24 &
cargo run -- -T 200 -n 1000 brahms -G samples -f 10 -t 300 -v 100 -u 100 -k 0 -r 1 > text30 &
cargo run -- -T 200 -n 1000 brahms -G samples -f 10 -t 360 -v 100 -u 100 -k 0 -r 1 > text36 &
cargo run -- -T 200 -n 1000 brahms -G samples -f 10 -t 400 -v 100 -u 100 -k 0 -r 1 > text40 &
cargo run -- -T 200 -n 1000 brahms -G samples -f 10 -t 500 -v 100 -u 100 -k 0 -r 1 > text50
