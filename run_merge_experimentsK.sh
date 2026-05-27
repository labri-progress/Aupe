#!/bin/bash

# run_merge_experimentsK.sh $STRATEGY $BUDGET $NRUNS
# run_merge_experimentsK.sh 1 10 decay 4

# Experiment parameters
ROUNDS=500 # 200
NODES=1000
VIEW=20 #16
UVIEW=20 #16
SM=15 #30
FORCE=10
NRUNS="${4:-1}" #5
echo "Running merge experiments with strategy=bm, budget=${1:-0.5}KB, runs=${NRUNS}"
# Faulty: 30% of N
FAULTY_PCT="${2:-26}"
FAULTY_COUNT=$(echo "$NODES * $FAULTY_PCT / 100" | bc)

STRATEGIES=("${3:-decay}") #"xdec")

# Budget memory in KB (only used by # ("${1:-decay}")bm via -y)
BUDGETS=("${1:-0.5}") #(5 10 20)

# Trusted node percentages -> number of trusted nodes
TRUSTED_PCTS=(0 5 20) #5 10 20 30)
# Corresponding -x values: 10%=1000, 20%=2000, 30%=3000
TRUSTED_COUNTS=(0 50 200) # 100 200) # 100 200) # 2000 3000)

# Number of merges per trusted node per round
MERGES=(1) # (1 10)

# Output directory
OUTDIR="results_merge"
mkdir -p "$OUTDIR"

MANIFEST="$OUTDIR/manifest.txt"
touch "$MANIFEST"

# Check if experiment is already done (listed in manifest)
is_done() {
    grep -qxF "$1" "$MANIFEST" 2>/dev/null
}

# Record experiment as done in manifest
mark_done() {
    echo "$1" >> "$MANIFEST"
}

for run in $(seq 1 $NRUNS); do
  for strat in "${STRATEGIES[@]}"; do
    for i in "${!TRUSTED_PCTS[@]}"; do
      t_pct=${TRUSTED_PCTS[$i]}
      t_count=${TRUSTED_COUNTS[$i]}

      for p in "${MERGES[@]}"; do
        if [ "$strat" = "array" ]; then
          # Array has no budget param
          outfile="${strat}-${NODES}-${VIEW}-${FAULTY_COUNT}-${t_count}-${p}-run${run}"
          if is_done "$outfile"; then
            echo "Skipping (already done): $outfile"
            continue
          fi
          echo "Running: $strat t=${t_pct}% p=${p} run=${run}"
          cargo run -- -T $ROUNDS -n $NODES $strat \
            -f $FORCE -t $FAULTY_COUNT -v $VIEW -u $UVIEW -m $SM \
            -n $NODES -x $t_count -p $p > "$OUTDIR/$outfile" &
          mark_done "$outfile"
        else
          # bm uses -y for budget
          for budget in "${BUDGETS[@]}"; do
            outfile="${strat}-${NODES}-${VIEW}-${FAULTY_COUNT}-${t_count}-${p}-${budget}-run${run}"
            if is_done "$outfile"; then
              echo "Skipping (already done): $outfile"
              continue
            fi
            echo "Running: $strat t=${t_pct}% p=${p} budget=${budget}KB run=${run}"

            cargo run -- -T $ROUNDS -n $NODES $strat \
              -f $FORCE -t $FAULTY_COUNT -v $VIEW -u $UVIEW -m $SM \
              -n $NODES -y $budget -x $t_count -p $p > "$OUTDIR/$outfile"
            mark_done "$outfile"
          done
        fi
      done
    done
  done
done

echo "All merge experiments done."
