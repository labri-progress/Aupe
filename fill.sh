#!/bin/sh
mkdir rho1
cargo run -- -T 200 -n 10000 brahms -G samples -f 10 -t 3600 -v 160 -u 160 -k 1 -r 1 > rho1/text36 &
cargo run -- -T 200 -n 10000 brahms -G samples -f 10 -t 4000 -v 160 -u 160 -k 1 -r 1 > rho1/text40 &
cargo run -- -T 200 -n 10000 brahms -G samples -f 10 -t 5000 -v 160 -u 160 -k 1 -r 1 > rho1/text50 

mkdir rho0
cargo run -- -T 200 -n 10000 brahms -G samples -f 10 -t 3600 -v 160 -u 160 -k 0 -r 1 > rho0/text36 &
cargo run -- -T 200 -n 10000 brahms -G samples -f 10 -t 4000 -v 160 -u 160 -k 0 -r 1 > rho0/text40 &
cargo run -- -T 200 -n 10000 brahms -G samples -f 10 -t 5000 -v 160 -u 160 -k 0 -r 1 > rho0/text50 
