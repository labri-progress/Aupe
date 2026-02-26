./run_experimentsK.sh bm 1 30 0
./run_experimentsK.sh decay 1 30 0
./run_experimentsK.sh bm 1 20 0
./run_experimentsK.sh decay 1 20 0
./run_experimentsK.sh bm 1 10 0
./run_experimentsK.sh decay 1 10 0
./run_experimentsK.sh array 1 30 0
./run_experimentsK.sh array 1 20 0
./run_experimentsK.sh array 1 10 0

exit 0

./run_NOmerge_expeK.sh decay 5 10
./run_NOmerge_expeK.sh decay 5 30
./run_NOmerge_expeK.sh decay 5 20
./run_NOmerge_expeK.sh decay 20 10
./run_NOmerge_expeK.sh decay 20 30
./run_NOmerge_expeK.sh decay 20 20

./run_NOmerge_expeK.sh decay 10 10
./run_NOmerge_expeK.sh decay 10 30
./run_NOmerge_expeK.sh decay 10 20
./run_NOmerge_expeK.sh decay 10 22
./run_NOmerge_expeK.sh decay 10 24
./run_NOmerge_expeK.sh decay 10 26
./run_NOmerge_expeK.sh decay 10 28

***
./run_merge_experimentsK.sh bm 1 30
./run_merge_experimentsK.sh decay 1 30
./run_merge_experimentsK.sh bm 1 20
./run_merge_experimentsK.sh decay 1 20
./run_merge_experimentsK.sh bm 1 10
./run_merge_experimentsK.sh decay 1 10

exit 0
Rscript plot_byz.r 1

Rscript plot_resilience_decay.r 30 1 10   # f=30%, budget=1, p_merge=10

Rscript plot_metrics_evolution.r 1 30           # t=0%, p=10 (defaults)
Rscript plot_metrics_evolution.r 1 30 10 10     # t=10%, p=10

