
# evolution de la résilience
Rscript plot_byz.r 0.5
#evolution des metriques internes des sketch de snoeuds
Rscript plot_metrics.r 0.5

# resilience en fonction de f
Rscript plot_resilience_decay.r 1 bm 200 # budget=1 strategy=bm round p_merge=10
# boxplot des metriques honest vs trusted - evolution par rounds
Rscript plot_metrics_evolution.r 1 26 10 bm 200 # f=26% t=10% strategy=bm round p=10 
# evolution de la resilience par rounds
Rscript plot_trusted.r 26 1 bm   # f=26%, budget=1, strategy=bm
# boxplot des metriques honest pour # prop de trusted node - evolution par rounds
Rscript plot_metrics_evol_bytrust.r 1 26 bm 200 # budget=1 f=26% strategy=bm, round p_merge=10