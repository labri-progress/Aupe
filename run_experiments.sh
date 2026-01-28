#!/bin/bash

# Experiment parameters
ROUNDS=100000
NODES=1000
VIEW=100
UVIEW=100
SM=100
GAMMA=10
NRUNS=5

# Strategies
STRATEGIES=("bm" "decay" "array")

# Budget values (KB) — used as -y for bm and decay; array has no budget param
BUDGETS=(1 2)

# Faulty percentages
FAULTY_PCTS=(10 20 30)

# Output directory
OUTDIR="results_byz"
mkdir -p "$OUTDIR"

# Compute number of faulty nodes from percentage
faulty_count() {
    echo $(( NODES * $1 / 100 ))
}

for run in $(seq 1 $NRUNS); do
  for strat in "${STRATEGIES[@]}"; do
    for f_pct in "${FAULTY_PCTS[@]}"; do
      f_count=$(faulty_count $f_pct)

      if [ "$strat" = "array" ]; then
        # Array has no budget parameter — run once per (f, run)
        outfile="$OUTDIR/${strat}-N${NODES}-v${VIEW}-f${f_pct}-run${run}"
        echo "Running: $strat f=${f_pct}% run=${run}"
        cargo run -- -T $ROUNDS -n $NODES $strat \
          -f $f_pct -t $f_count -v $VIEW -u $UVIEW -m $SM \
          -n $NODES > "$outfile"
      else
        # bm and decay use -y for budget
        for budget in "${BUDGETS[@]}"; do
          outfile="$OUTDIR/${strat}-N${NODES}-v${VIEW}-f${f_pct}-y${budget}-run${run}"
          echo "Running: $strat f=${f_pct}% budget=${budget}KB run=${run}"
          cargo run -- -T $ROUNDS -n $NODES $strat \
            -f $f_pct -t $f_count -v $VIEW -u $UVIEW -m $SM \
            -n $NODES -y $budget > "$outfile"
        done
      fi
    done
  done
done

echo "All experiments done."
