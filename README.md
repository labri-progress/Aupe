# Aupe

Run in release mode (much faster):
cargo run --release -- -T 1000 -n 1000 decay -G samples -f 10 -t 300 -v 100 -u 100 -m 10 -n 1000 -y 1

./run_experiments.sh
Rscript plot_byz.r 1 (for budget=1KB) or Rscript plot_byz.r 2

./run_merge_experiments.sh 
Rscript plot_merge.r 30 10 1

run_merge_experimentsK.sh $STRATEGY $BUDGET $NRUNS
./run_merge_experimentsK.sh bm 10 1
./run_merge_experimentsK.sh bm 20 1
./run_merge_experimentsK.sh array 10 1


./run_experimentsK.sh bm 30 1
./run_experimentsK.sh array 30 1
./run_experimentsK.sh decay 30 1

./run_experimentsK.sh bm 40 1
./run_experimentsK.sh array 40 1
./run_experimentsK.sh decay 40 1
