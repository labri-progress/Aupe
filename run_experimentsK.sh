#!/bin/bash
# ./run_experimentsK.sh decay 0.5 30 10 [1]

# Experiment parameters
ROUNDS=1 # 600000
NODES=1000
VIEW=20
UVIEW=20
SM=30
GAMMA=10 #20
NRUNS="${5:-1}" #5
ATTACK_START=10000
# Strategies
STRATEGIES=("${1:-bm}") #("decay" "array" "bm")

# Budget values (KB) — used as -y for bm and decay; array has no budget param
BUDGETS=("${2:-0.5}")

# Faulty percentages
FAULTY_PCTS=("${3:-30}") #10 20 30

TRUSTED_PCTS=("${4:-0}") # 0 10 20 30
# Trusted node counts (0 = no trusted nodes)


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

      for t_pct in "${TRUSTED_PCTS[@]}"; do
        t_count=$(( NODES * t_pct / 100 ))
        # Build trusted flags
        if [ "$t_count" -gt 0 ]; then
          trusted_flags="-x $t_count -p 10"
          trusted_tag="-x${t_count}"
        else
          trusted_flags=""
          trusted_tag=""
        fi

        if [ "$strat" = "array" ]; then
          # Array has no budget parameter — run once per (f, run)
          outfile="${strat}-N${NODES}-v${VIEW}-f${f_count}${trusted_tag}-run${run}"
          if is_done "$outfile"; then
            echo "Skipping (already done): $outfile"
            continue
          fi
          echo "Running: $strat f=${f_pct}% t=${t_count} run=${run}"
          cargo run -- -T $ROUNDS -n $NODES $strat \
            -f $GAMMA -t $f_count -v $VIEW -u $UVIEW -m $SM \
            -n $NODES $trusted_flags -s $ATTACK_START > "$OUTDIR/$outfile" &
          mark_done "$outfile"
        else
          # bm and decay use -y for budget
          for budget in "${BUDGETS[@]}"; do
            buckets=$(echo "$budget * 1024/8/2" | bc)
            outfile="${strat}-N${NODES}-v${VIEW}-f${f_count}-y${budget}${trusted_tag}-run${run}"
            if is_done "$outfile"; then
              echo "Skipping (already done): $outfile"
              continue
            fi
            echo "Running: $strat f=${f_count} budget=${budget}KB t=${t_count} run=${run}"
            cargo run -- -T $ROUNDS -n $NODES $strat \
              -f $GAMMA -t $f_count -v $VIEW -u $UVIEW -m $SM \
              -n $NODES -c $buckets $trusted_flags -s $ATTACK_START > "$OUTDIR/$outfile" &
            mark_done "$outfile"
          done
        fi
      done
    done
  done
done

echo "All experiments done."
