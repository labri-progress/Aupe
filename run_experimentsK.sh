#!/bin/bash

# Experiment parameters
ROUNDS=2 #00000
NODES=1000
VIEW=100
UVIEW=100
SM=100
GAMMA=10
NRUNS="${3:-5}" #5

# Strategies
STRATEGIES=("${1:-bm}") #("decay" "array" "bm")

# Budget values (KB) — used as -y for bm and decay; array has no budget param
BUDGETS=(0.5 1 2)

# Faulty percentages
FAULTY_PCTS=("${1:-30}") #10 20 30

# Output directory
OUTDIR="results_byz"
mkdir -p "$OUTDIR"

MANIFEST="$OUTDIR/manifest.txt"
touch "$MANIFEST"

# Compute number of faulty nodes from percentage
faulty_count() {
    echo $(( NODES * $1 / 100 ))
}

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
    for f_pct in "${FAULTY_PCTS[@]}"; do
      f_count=$(faulty_count $f_pct)

      if [ "$strat" = "array" ]; then
        # Array has no budget parameter — run once per (f, run)
        outfile="${strat}-N${NODES}-v${VIEW}-f${f_count}-run${run}"
        if is_done "$outfile"; then
          echo "Skipping (already done): $outfile"
          continue
        fi
        #echo "Running: $strat f=${f_pct}% run=${run}"
        cargo run -- -T $ROUNDS -n $NODES $strat \
          -f $GAMMA -t $f_count -v $VIEW -u $UVIEW -m $SM \
          -n $NODES > "$OUTDIR/$outfile"
        mark_done "$outfile"
      else
        # bm and decay use -y for budget
        for budget in "${BUDGETS[@]}"; do
          buckets=$(echo "$budget * 1024/8/2" | bc)
          outfile="${strat}-N${NODES}-v${VIEW}-f${f_count}-y${budget}-run${run}"
          if is_done "$outfile"; then
            echo "Skipping (already done): $outfile"
            continue
          fi
          echo "Running: $strat f=${f_count} budget=${budget}KB run=${run}"
          cargo run -- -T $ROUNDS -n $NODES $strat \
            -f $GAMMA -t $f_count -v $VIEW -u $UVIEW -m $SM \
            -n $NODES -c $buckets > "$OUTDIR/$outfile"
          mark_done "$outfile"
        done
      fi
    done
  done
done

echo "All experiments done."
