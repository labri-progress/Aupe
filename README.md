# Aupe

./proba -T 20000 -n 1000 decay2 -f 10 -t 300 -v 20 -u 20 -m 15 -n 1000 -c 128 -p 1 -s 10000 > decay2_proba

./max_expe.sh decay4 0.5 10 0 ; ./max_expe.sh decay4 0.5 10 20 ;
./max_expe.sh decay4 0.5 20 0 ; ./max_expe.sh decay4 0.5 20 20 ;
./max_expe.sh decay4 0.5 30 0 ; ./max_expe.sh decay4 0.5 30 20 ;


./eviction -T 20000 -n 1000 decay2 -f 10 -t 300 -v 20 -u 20 -m 15 -n 1000 -c 128 -p 1 -s 10000 > decay2_2k0

./eviction -T 20000 -n 1000 decay2 -f 10 -t 300 -v 20 -u 20 -m 15 -n 1000 -c 32 -p 1 -s 10000 > debias_decay2

./two_debiais -T 20000 -n 1000 decay4 -f 10 -t 300 -v 20 -u 20 -m 15 -n 1000 -c 128 -p 1 -s 10000 > decay4_2k0

./two_debiais -T 20000 -n 1000 decay4 -f 10 -t 300 -v 20 -u 20 -m 15 -n 1000 -c 32 -p 1 -s 10000 > attack_decay4


./eviction -T 20000 -n 1000 decay4 -f 10 -t 300 -v 20 -u 20 -m 15 -n 1000 -c 32 -p 1 -s 10000 > onedebias_decay2


./max_expe.sh decay2 0.5 40 20 ; ./max_expe.sh decay2 0.5 40 5 ;
./max_expe.sh decay2 0.5 30 20 ; ./max_expe.sh decay2 0.5 30 5 ;
./max_expe.sh decay2 0.5 10 5 ; ./max_expe.sh decay2 0.5 10 20 ;

Rscript plot_slots_bytrust.r 6.0 10 decay 200 1 10000
Output : results/slots_bytrust_decay_f100_b6.0_x200.pdf

./max_expe.sh decay 0.5 30 20 ; ./max_expe.sh decay 0.5 30 5 ;
./max_expe.sh decay 0.5 10 0 ; ./max_expe.sh decay 0.5 10 20 ;



./run_merge_experimentsK.sh 0.5 30

./max_expe.sh decay2 0.5 40 5 ; ./max_expe.sh decay2 0.5 40 20 ;
./max_expe.sh decay2 0.5 40 0 ; ./max_expe.sh decay2 0.5 40 10 ;

./max_expe.sh decay2 0.5 35 5 ; ./max_expe.sh decay2 0.5 35 20 ;
./max_expe.sh decay2 0.5 35 0 ; ./max_expe.sh decay2 0.5 35 10 

./max_expe.sh decay2 0.5 30 5 ; ./max_expe.sh decay2 0.5 30 20 ;
./max_expe.sh decay2 0.5 30 0 ; ./max_expe.sh decay2 0.5 30 10 ;

./max_expe.sh decay2 0.5 25 5 ; ./max_expe.sh decay2 0.5 25 20 ;
./max_expe.sh decay2 0.5 25 0 ; ./max_expe.sh decay2 0.5 25 10 

./max_expe.sh decay2 0.5 20 5 ; ./max_expe.sh decay2 0.5 20 20 ;
./max_expe.sh decay2 0.5 20 0 ; ./max_expe.sh decay2 0.5 20 10 

./max_expe.sh decay2 0.5 10 5 ; ./max_expe.sh decay2 0.5 10 20 ;
./max_expe.sh decay2 0.5 10 0 ; ./max_expe.sh decay2 0.5 10 10 ;




- remove conditionnal pull requests of trusted nodes
- test without eviction rate and samplek of push and pull bags
./max_expe.sh evict 0.5 30 0 ; ./max_expe.sh evict 0.5 30 5 ; ./max_expe.sh evict 0.5 30 20 ;

./max_expe.sh evict 0.5 10 0 ; ./max_expe.sh evict 0.5 10 5 ; ./max_expe.sh evict 0.5 10 20 ;

./max_expe.sh evict 0.5 20 0 ; ./max_expe.sh evict 0.5 20 5 ; ./max_expe.sh evict 0.5 20 20 ; 

./max_expe.sh array 0.5 30 0 ; ./max_expe.sh array 0.5 20 0 ; ./max_expe.sh array 0.5 10 0 ;

./max_expe.sh brahms 0.5 30 0 ; ./max_expe.sh brahms 0.5 20 0 ; ./max_expe.sh brahms 0.5 10 0 ;


./max_expe.sh bm 0.5 10 0 ; ./max_expe.sh bm 0.5 20 0 ; ./max_expe.sh bm 0.5 30 0 ;

./max_expe.sh decay 0.5 30 5 ; ./max_expe.sh decay 0.5 30 20 ; ./max_expe.sh decay 0.5 10 5 ; 

 ./max_expe.sh decay 0.5 20 5 ; ./max_expe.sh decay 0.5 20 20 ; ./max_expe.sh decay 0.5 10 20 ;


chartreuse3-1.grenoble.grid5000.fr
chartreuse3-3.grenoble.grid5000.fr
chartreuse3-4.grenoble.grid5000.fr
chartreuse4-1.grenoble.grid5000.fr
chartreuse4-2.grenoble.grid5000.fr
chartreuse4-3.grenoble.grid5000.fr
chartreuse4-4.grenoble.grid5000.fr
./max_expe.sh decay 0.5 30 0 ; ./max_expe.sh decay 0.5 20 0 ; ./max_expe.sh decay 0.5 10 0 ; 



./run_experimentsK.sh evict 0.5 30 0 ; ./run_experimentsK.sh evict 0.5 30 5 ; ./run_experimentsK.sh evict 0.5 30 20 ;

./run_experimentsK.sh evict 0.5 10 0 ; ./run_experimentsK.sh evict 0.5 10 5 ; ./run_experimentsK.sh evict 0.5 10 20 ;

./run_experimentsK.sh evict 0.5 20 0 ; ./run_experimentsK.sh evict 0.5 20 5 ; ./run_experimentsK.sh evict 0.5 20 20 ; 


./run_experimentsK.sh evict 0.5 40 0 ; ./run_experimentsK.sh evict 0.5 40 5 ; ./run_experimentsK.sh evict 0.5 40 20 ; 

./run_experimentsK.sh decay 0.5 30 0 ; ./run_experimentsK.sh decay 0.5 20 0 ; ./run_experimentsK.sh decay 0.5 10 0 ; 

./run_experimentsK.sh decay 0.5 40 0 ; ./run_experimentsK.sh bm 0.5 40 0 ; ./run_experimentsK.sh bm 0.5 30 0 ;


 ./run_experimentsK.sh bm 0.5 20 0 ; ./run_experimentsK.sh bm 0.5 10 0 ; ./run_experimentsK.sh array 0.5 40 0;


./run_experimentsK.sh array 0.5 30 0 ; ./run_experimentsK.sh array 0.5 20 0 ; ./run_experimentsK.sh array 0.5 10 0 ;



./max_expe.sh decay 0.5 30 5; ./max_expe.sh decay 0.5 30 10

./run_experimentsK.sh decay 0.5 30 0 ; ./run_experimentsK.sh decay 0.5 30 5
./run_experimentsK.sh decay 0.5 20 0 ; ./run_experimentsK.sh decay 0.5 20 5
./run_experimentsK.sh decay 0.5 10 0 ; ./run_experimentsK.sh decay 0.5 10 5

./run_experimentsK.sh decay 0.5 30 10 ; ./run_experimentsK.sh decay 0.5 30 20
./run_experimentsK.sh decay 0.5 20 10 ; ./run_experimentsK.sh decay 0.5 20 20
./run_experimentsK.sh decay 0.5 10 10 ; ./run_experimentsK.sh decay 0.5 10 20




./run_experimentsK.sh xdec 0.5 30 0 ; ./run_experimentsK.sh xdec 0.5 30 20

./run_experimentsK.sh xbm 0.5 30 0 ; ./run_experimentsK.sh xbm 0.5 30 20

./run_experimentsK.sh xarray 0.5 30 0 ; ./run_experimentsK.sh xarray 0.5 30 20

TODO
./run_10000K.sh decay 10 30 0

./run_merge_experimentsK.sh 1 [10,20,26,30]
./run_merge_experimentsK.sh 1 [10,20,30]


./run_experimentsK.sh evict 0.5 30 0 ; ./run_experimentsK.sh evict 0.5 30 5
./run_experimentsK.sh evict 0.5 20 0 ; ./run_experimentsK.sh evict 0.5 20 5
./run_experimentsK.sh evict 0.5 10 0 ; ./run_experimentsK.sh evict 0.5 10 5

./run_experimentsK.sh evict 0.5 30 10 ; ./run_experimentsK.sh evict 0.5 30 20
./run_experimentsK.sh evict 0.5 20 10 ; ./run_experimentsK.sh evict 0.5 20 20
./run_experimentsK.sh evict 0.5 10 10 ; ./run_experimentsK.sh evict 0.5 10 20


./run_experimentsK.sh xdec 0.5 30 0 ; ./run_experimentsK.sh xdec 0.5 30 5
./run_experimentsK.sh xdec 0.5 20 0 ; ./run_experimentsK.sh xdec 0.5 20 5
./run_experimentsK.sh xdec 0.5 10 0 ; ./run_experimentsK.sh xdec 0.5 10 5

./run_experimentsK.sh xdec 0.5 30 10 ; ./run_experimentsK.sh xdec 0.5 30 20
./run_experimentsK.sh xdec 0.5 20 10 ; ./run_experimentsK.sh xdec 0.5 20 20
./run_experimentsK.sh xdec 0.5 10 10 ; ./run_experimentsK.sh xdec 0.5 10 20

./run_experimentsK.sh xbm 0.5 30 0 ; ./run_experimentsK.sh xbm 0.5 20 0 ; ./run_experimentsK.sh xbm 0.5 10 0

./run_experimentsK.sh xarray 0.5 30 0 ; ./run_experimentsK.sh xarray 0.5 20 0 ; ./run_experimentsK.sh xarray 0.5 10 0





./run_merge_attack.sh decay 1 10

./run_merge_float.sh 0.5 10

./run_merge_experimentsK.sh 3 [10,20,26,30]
./run_merge_experimentsK.sh 3 [10,20,30]


./run_experimentsK.sh decay 0.5 30 10 ; ./run_experimentsK.sh decay 0.5 30 20
./run_experimentsK.sh decay 0.5 20 10 ; ./run_experimentsK.sh decay 0.5 20 20
./run_experimentsK.sh decay 0.5 10 10 ; ./run_experimentsK.sh decay 0.5 10 20

./run_experimentsK.sh decay 0.5 30 5 ; ./run_experimentsK.sh decay 0.5 20 5
./run_experimentsK.sh decay 0.5 10 5 ; ./run_experimentsK.sh array 0.5 30 0 


./run_experimentsK.sh bm 0.5 30 0 ; ./run_experimentsK.sh bm 0.5 20 0
./run_experimentsK.sh decay 0.5 30 0 ; ./run_experimentsK.sh decay 0.5 20 0
./run_experimentsK.sh bm 0.5 10 0 ; ./run_experimentsK.sh decay 0.5 10 0


./run_experimentsK.sh array 0.5 10 0; ./run_experimentsK.sh array 0.5 20 0

./run_merge_experimentsK.sh decay 1 40
./run_merge_experimentsK.sh decay 1 30
./run_merge_experimentsK.sh decay 1 20
./run_merge_experimentsK.sh decay 1 [22,24,26,28]
./run_merge_experimentsK.sh decay 1 [12,14,16,18]
./run_merge_experimentsK.sh decay 1 10

Rscript plot_resilience_decay.r 1 10
Rscript plot_metrics_evolution.r 1 30
Rscript plot_mergeandNomerge.r 30 1 10


./run_experimentsK.sh bm 1 30 0
./run_experimentsK.sh decay 1 30 0
./run_experimentsK.sh bm 1 20 0
./run_experimentsK.sh decay 1 20 0
./run_experimentsK.sh bm 1 10 0
./run_experimentsK.sh decay 1 10 0
./run_experimentsK.sh array 1 30 0
./run_experimentsK.sh array 1 20 0
./run_experimentsK.sh array 1 10 0


./run_experimentsK.sh decay 1 30 10
./run_experimentsK.sh decay 1 30 10
./run_experimentsK.sh decay 1 30 10



./run_experimentsK.sh bm 30 0 1
./run_experimentsK.sh decay 30 0 1
./run_experimentsK.sh bm 20 0 1
./run_experimentsK.sh decay 20 0 1
./run_experimentsK.sh bm 10 0 1
./run_experimentsK.sh decay 10 0 1
./run_experimentsK.sh decay 40 0 1


./run_experimentsK.sh bm 30 10 1
./run_experimentsK.sh decay 30 10 1
./run_experimentsK.sh bm 20 10 1
./run_experimentsK.sh decay 20 10 1
./run_experimentsK.sh bm 10 10 1
./run_experimentsK.sh decay 10 10 1


oarsub -l host=4,walltime=12 -t deploy -p grappe -r '2026-02-03 02:00:02'





PREVIOUS

Run in release mode (much faster):
cargo run --release -- -T 1000 -n 1000 decay -f 10 -t 300 -v 100 -u 100 -m 100 -n 1000 -y 1

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
