#!/bin/bash
# ./run_experimentsK.sh decay 0.5 30 10 [1] [eviction_rate]

# Experiment parameters
ROUNDS=20000 # 600000
NODES=1000
VIEW=20
UVIEW=20
SM=15 #30
GAMMA=10 #20
NRUNS="${6:-1}" #5
ATTACK_START=10000
# Strategies
STRATEGIES=("${1:-bm}") #("decay" "array" "bm")

# Budget values (KB) — used as -y for bm and decay; array has no budget param
BUDGETS=("${2:-0.5}")

# Faulty percentages
FAULTY_PCTS=("${3:-30}") #10 20 30

TRUSTED_PCTS=("${4:-0}") # 0 10 20 30

# Eviction rates for trusted nodes (0.0 = no eviction)
EVICTION_RATES=0.5 #("${6:-0.5}") # 0.0 0.5 0.8
# Trusted node counts (0 = no trusted nodes)

numberofmerge=("${5:-1}")
# Output directory
OUTDIR="results_merge"
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

start=2
if [ "$NRUNS" -eq 1 ]; then
  start=1
fi

binary="eviction" #"aupe1push13pullmax"
#for run in $(seq $start $NRUNS); do
for run in $(seq $NRUNS -1 $start); do
  for strat in "${STRATEGIES[@]}"; do
    for f_pct in "${FAULTY_PCTS[@]}"; do
      f_count=$(faulty_count $f_pct)

      for t_pct in "${TRUSTED_PCTS[@]}"; do
        t_count=$(( NODES * t_pct / 100 ))
        # Build trusted flags
        if [ "$t_count" -gt 0 ]; then
          trusted_flags="-x $t_count -p $numberofmerge" # -p 1 means One merge per round for trusted nodes
          trusted_tag="-x${t_count}"
        else
          trusted_flags="-p $numberofmerge"
          trusted_tag=""
        fi

        if [ "$strat" = "brahms" ]; then
          outfile="${strat}-N${NODES}-v${VIEW}-f${f_count}-run${run}"
          if is_done "$outfile"; then
            echo "Skipping (already done): $outfile"
            continue
          fi
          echo "Running: $strat f=${f_pct}% run=${run}"
          ./$binary -T $ROUNDS -n $NODES -d $run $strat \
            -f $GAMMA -t $f_count -v $VIEW -u $UVIEW \
            -s $ATTACK_START  > "$OUTDIR/$outfile" &
          mark_done "$outfile"
        
        elif [ "$strat" = "basalt" ]; then
          outfile="${strat}-N${NODES}-v${VIEW}-f${f_count}-run${run}"
          if is_done "$outfile"; then
            echo "Skipping (already done): $outfile"
            continue
          fi
          echo "Running: $strat f=${f_pct}% run=${run}"
          ./$binary -T $ROUNDS -n $NODES -d $run $strat \
            -f $GAMMA -t $f_count -v $VIEW -i $UVIEW \
            -s $ATTACK_START -k 1 -r 2 > "$OUTDIR/$outfile" &
          mark_done "$outfile"

        elif [ "$strat" = "array" ] || [ "$strat" = "xarray" ]; then
          # Array has no budget parameter — run once per (f, run)
          outfile="${strat}-N${NODES}-v${VIEW}-f${f_count}${trusted_tag}-run${run}"
          if is_done "$outfile"; then
            echo "Skipping (already done): $outfile"
            continue
          fi
          echo "Running: $strat f=${f_pct}% t=${t_count} run=${run}"
          ./$binary -T $ROUNDS -n $NODES -d $run $strat \
            -f $GAMMA -t $f_count -v $VIEW -u $UVIEW -m $SM \
            -n $NODES $trusted_flags -s $ATTACK_START  > "$OUTDIR/$outfile" &
          mark_done "$outfile"
          
        elif [ "$strat" = "bm" ] || [ "$strat" = "decay" ] || [ "$strat" = "decay2" ] || [ "$strat" = "decay4" ]; then
          for budget in "${BUDGETS[@]}"; do
            buckets=$(echo "$budget * 1024/8/2" | bc)
            outfile="${strat}-N${NODES}-v${VIEW}-f${f_count}-y${budget}${trusted_tag}-run${run}"
            if is_done "$outfile"; then
              echo "Skipping (already done): $outfile"
              continue
            fi
            echo "Running: $strat f=${f_count} budget=${budget}KB t=${t_count} run=${run}"
            ./$binary -T $ROUNDS -n $NODES -d $run $strat \
              -f $GAMMA -t $f_count -v $VIEW -u $UVIEW -m $SM \
              -n $NODES -c $buckets $trusted_flags -s $ATTACK_START > "$OUTDIR/$outfile" &
            mark_done "$outfile"
            
          done
          
          else
          # bm and decay use -y for budget
          for budget in "${BUDGETS[@]}"; do
            buckets=$(echo "$budget * 1024/8/2" | bc)
            for eviction_rate in "${EVICTION_RATES[@]}"; do
              eviction_tag=$([ "$eviction_rate" != "0.0" ] && echo "-e${eviction_rate}" || echo "")
              outfile="${strat}-N${NODES}-v${VIEW}-f${f_count}-y${budget}${trusted_tag}${eviction_tag}-run${run}"
              if is_done "$outfile"; then
                echo "Skipping (already done): $outfile"
                continue
              fi
              echo "Running: $strat f=${f_count} budget=${budget}KB t=${t_count} eviction=${eviction_rate} run=${run}"
              ./$binary -T $ROUNDS -n $NODES -d $run $strat \
                -f $GAMMA -t $f_count -v $VIEW -u $UVIEW -m $SM \
                -n $NODES -c $buckets $trusted_flags -s $ATTACK_START -e $eviction_rate > "$OUTDIR/$outfile" &
              mark_done "$outfile"
            done
          done
        fi
      done
    done
  done
 # wait
done

echo "All experiments done."
