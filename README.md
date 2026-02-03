# Aupe
TODO

./run_experimentsK.sh bm 30 1

cargo run -- -T 1000000 -n 1000 decay -f 10 -t 300 -v 100 -u 100 -m 100 -n 1000 -c 12 -x 300 -p 10 > results_merge/decay-1000-100-300-300-10-0.2-run1


cargo run -- -T 1000000 -n 1000 decay -f 10 -t 300 -v 100 -u 100 -m 100 -n 1000 -c 12 -x 300 -p 1 > results_merge/decay-1000-100-300-300-1-0.2-run1


oarsub -l host=4,walltime=12 -t deploy -p grappe -r '2026-02-03 02:00:02'





PREVIOUS

Run in release mode (much faster):
cargo run --release -- -T 1000 -n 1000 decay -G samples -f 10 -t 300 -v 100 -u 100 -m 10 -n 1000 -y 1

./run_experiments.sh
Rscript plot_byz.r 1 (for budget=1KB) or Rscript plot_byz.r 2

./run_merge_experiments.sh 
Rscript plot_merge.r 30 10 1

run_merge_experimentsK.sh $STRATEGY $BUDGET $NRUNS

only Nrun 1 and 2 

REDO for t=5% REMOVE 30
./run_merge_experimentsK.sh bm 10 1 2
./run_merge_experimentsK.sh bm 20 1 2
./run_merge_experimentsK.sh array 10 1 2


./run_experimentsK.sh bm 30 1 2
./run_experimentsK.sh array 30 1 2
./run_experimentsK.sh decay 30 1 2

./run_experimentsK.sh bm 40 1 2
./run_experimentsK.sh array 40 1 2
./run_experimentsK.sh decay 40 1 2

Rscript plot_byz.r 1
 Rscript plot_byz.r 2
 Rscript plot_byzfloat.r 0.5

Rscript plot_merge.r 30 10 10
Rscript plot_merge.r 30 20 10
Rscript plot_mergeandNomergecopy.r 30 10 10
Rscript plot_mergeandNomerge.r 30 5 10


BUDGET 5
./run_merge_experimentsK.sh bm 5 1

NOMERGE

./run_NOmerge_expeK.sh bm 5 1 2
./run_NOmerge_expeK.sh bm 10 1 2
./run_NOmerge_expeK.sh array 10 1 2
./run_NOmerge_expeK.sh bm 20 1 2

./run_experimentsK.sh bm 20 1 2

WAITING
./run_experimentsK.sh array 20 1 2
./run_experimentsK.sh decay 20 1 2

./run_experimentsK.sh bm 10 1 2
./run_experimentsK.sh array 10 1 *


./run_experimentsK.sh decay 10 1 2

./run_NOmerge_expeK.sh decay 5 1
./run_NOmerge_expeK.sh decay 10 1
./run_NOmerge_expeK.sh decay 20 1

./run_merge_experimentsK.sh decay 5 1
./run_merge_experimentsK.sh decay 10 1
./run_merge_experimentsK.sh decay 20 1

cargo run -- -T 200 -n 10000 array -f 10 -t 3000 -v 160 -u 160 -m 100 -n 10000 -x 100 -p 10 > results_merge/array-10000-160-3000-100-10-run1

cargo run -- -T 200 -n 10000 bm -f 10 -t 3000 -v 160 -u 160 -m 100 -n 10000 -y 20 -x 100 -p 10 > results_merge/bm-10000-160-3000-100-10-20-run1

cargo run -- -T 200 -n 10000 bm -f 10 -t 3000 -v 160 -u 160 -m 100 -n 10000 -y 10 -x 100 -p 10 > results_merge/bm-10000-160-3000-100-10-10-run1

cargo run -- -T 200 -n 10000 bm -f 10 -t 3000 -v 160 -u 160 -m 100 -n 10000 -y 5 -x 100 -p 10 > results_merge/bm-10000-160-3000-100-10-5-run1



TODO

cargo run -- -T 2000 -n 10000 decay -f 10 -t 3000 -v 160 -u 160 -m 100 -n 10000 -y 20 -x 3000 -p 10 > results_merge/decay-10000-160-3000-3000-10-20-run1

cargo run -- -T 2000 -n 10000 decay -f 10 -t 3000 -v 160 -u 160 -m 100 -n 10000 -y 20 > results_merge/decay-10000-160-3000-0-10-20-run1