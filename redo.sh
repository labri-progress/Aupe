mkdir analysis

cargo run -- -T 2000 -n 10000 bm -f 10 -t 3000 -v 160 -u 160 -m 100 \
    -n 10000 -y 10 > "analysis/bm-10-3000-10"

cargo run -- -T 2000 -n 10000 kvs -f 10 -t 1000 -v 160 -u 160 -m 100 \
    -n 10000 > "analysis/kvs-10-1000"
            
cargo run -- -T 2000 -n 10000 kvs -f 10 -t 2000 -v 160 -u 160 -m 100 \
    -n 10000 > "analysis/kvs-10-2000"

cargo run -- -T 2000 -n 10000 kvs -f 10 -t 3000 -v 160 -u 160 -m 100 \
    -n 10000 > "analysis/kvs-10-3000"


cargo run -- -T 2000 -n 10000 bm -f 2 -t 3000 -v 160 -u 160 -m 100 \
    -n 10000 -y 10 > "analysis/bm-2-3000-10"

cargo run -- -T 2000 -n 10000 bm -f 2 -t 3000 -v 160 -u 160 -m 100 \
    -n 10000 -y 20 > "analysis/bm-2-3000-20"
            
cargo run -- -T 2000 -n 10000 bm -f 2 -t 3000 -v 160 -u 160 -m 100 \
    -n 10000 -y 30 > "analysis/bm-2-3000-30"

cargo run -- -T 2000 -n 10000 bm -f 2 -t 3000 -v 160 -u 160 -m 100 \
    -n 10000 -y 40 > "analysis/bm-2-3000-40"

cargo run -- -T 2000 -n 10000 bm -f 2 -t 2000 -v 160 -u 160 -m 100 \
    -n 10000 -y 40 > "analysis/bm-2-2000-40"

cargo run -- -T 2000 -n 10000 kvs -f 2 -t 1000 -v 160 -u 160 -m 100 \
    -n 10000 > "analysis/kvs-2-1000"
            
cargo run -- -T 2000 -n 10000 kvs -f 2 -t 2000 -v 160 -u 160 -m 100 \
    -n 10000 > "analysis/kvs-2-2000"

cargo run -- -T 200 -n 10000 decay -f 10 -t 2600 -v 160 -u 160 -m 100 -n 10000 -y 10 > "decay-2600" 
cargo run -- -T 200 -n 10000 decay -f 10 -t 2600 -v 160 -u 160 -m 100 -n 10000 -y 10 -x 1000 -p 10 > "decay-2600-1000" #2h

cargo run -- -T 200 -n 10000 bm -f 10 -t 2600 -v 160 -u 160 -m 100 -n 10000 -y 10 > "bm-2600"
cargo run -- -T 200 -n 10000 bm -f 10 -t 2600 -v 160 -u 160 -m 100 -n 10000 -y 10 -x 1000 -p 10 > "bm-2600-1000" #2h