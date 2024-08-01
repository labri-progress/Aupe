#!/bin/sh

wait
mkdir rho0
cargo run -- -T 200 -n 10000 brahms -G samples -f 10 -t 800 -v 160 -u 160 -k 0 -r 1 > rho0/text8 &
cargo run -- -T 200 -n 10000 brahms -G samples -f 10 -t 1000 -v 160 -u 160 -k 0 -r 1 > rho0/text10 &
cargo run -- -T 200 -n 10000 brahms -G samples -f 10 -t 1200 -v 160 -u 160 -k 0 -r 1 > rho0/text12 &
cargo run -- -T 200 -n 10000 brahms -G samples -f 10 -t 1400 -v 160 -u 160 -k 0 -r 1 > rho0/text14 &
cargo run -- -T 200 -n 10000 brahms -G samples -f 10 -t 1600 -v 160 -u 160 -k 0 -r 1 > rho0/text16 &
cargo run -- -T 200 -n 10000 brahms -G samples -f 10 -t 1800 -v 160 -u 160 -k 0 -r 1 > rho0/text18 &
cargo run -- -T 200 -n 10000 brahms -G samples -f 10 -t 2000 -v 160 -u 160 -k 0 -r 1 > rho0/text20 &
wait
cargo run -- -T 200 -n 10000 brahms -G samples -f 10 -t 2200 -v 160 -u 160 -k 0 -r 1 > rho0/text22 &
cargo run -- -T 200 -n 10000 brahms -G samples -f 10 -t 2400 -v 160 -u 160 -k 0 -r 1 > rho0/text24 &
cargo run -- -T 200 -n 10000 brahms -G samples -f 10 -t 2600 -v 160 -u 160 -k 0 -r 1 > rho0/text26 &
cargo run -- -T 200 -n 10000 brahms -G samples -f 10 -t 2800 -v 160 -u 160 -k 0 -r 1 > rho0/text28 &
cargo run -- -T 200 -n 10000 brahms -G samples -f 10 -t 3000 -v 160 -u 160 -k 0 -r 1 > rho0/text30 &
#cargo run -- -T 200 -n 10000 brahms -G samples -f 10 -t 3600 -v 160 -u 160 -k 0 -r 1 > rho0/text36 &
#cargo run -- -T 200 -n 10000 brahms -G samples -f 10 -t 4000 -v 160 -u 160 -k 0 -r 1 > rho0/text40 &
#cargo run -- -T 200 -n 10000 brahms -G samples -f 10 -t 5000 -v 160 -u 160 -k 0 -r 1 > rho0/text50 
