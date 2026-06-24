round_from=9900
round_to=11000

Rscript fig1_evolution_strategies.r 0.5 &

Rscript fig1_evolution_strategies.r 0.5 $round_from $round_to &

Rscript fig2_convergence_summary.r 0.5 &

Rscript fig2_convergence_summary.r 0.5 $round_from $round_to &

Rscript fig3_merge_gain.r 0.5 &

Rscript fig3_merge_gain.r 0.5 $round_from $round_to &

Rscript fig4_attack_comparison.r 0.5 $round_from $round_to &

Rscript fig5_kmeans_nodes.r 0.5 &

Rscript fig6_trust_gap.r 0.5 &

Rscript fig7_baselines.r 0.5 &

Rscript fig7_baselines.r 0.5 9500 12500 &