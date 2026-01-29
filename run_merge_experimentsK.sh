#!/bin/bash

# run_merge_experimentsK.sh $STRATEGY $BUDGET $NRUNS

# Experiment parameters
ROUNDS=200
NODES=10000
VIEW=160
UVIEW=160
SM=100
FORCE=10
NRUNS="${3:-5}" #5

# Faulty: 30% of N
FAULTY_PCT=30
FAULTY_COUNT=3000

# Strategies (no decay for merge)
STRATEGIES=("${1:-bm}") #("bm" "array")

# Budget memory in KB (only used by bm via -y)
BUDGETS=("${2:-20}") #(10 20)

# Trusted node percentages -> number of trusted nodes
TRUSTED_PCTS=(10 20 30)
# Corresponding -x values: 10%=1000, 20%=2000, 30%=3000
TRUSTED_COUNTS=(1000 2000 3000)

# Number of merges per trusted node per round
MERGES=(10) # (1 10)

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

for run in $(seq $NRUNS $NRUNS); do
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
            -n $NODES -x $t_count -p $p > "$OUTDIR/$outfile"
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
