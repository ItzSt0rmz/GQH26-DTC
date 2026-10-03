#!/bin/bash
# Usage: ./run_stress.sh many | seeds | fullrange | edge
cd "$(dirname "$0")"
run() { RUN_TAG=$1 RANDOM_SEED=$2 PRICE_MAX=$3 PATTERN=${4:-random} ${PY:-python3} 23_stress_uart_test.py > /dev/null 2>&1
        echo "$1 seed=$2 pmax=$3: $(grep -E 'Correct packets|Timeouts' stress_results/$1.txt | tr '\n' ' ')"; }
case $1 in
  many)      for i in $(seq 1 10); do run many_$i 0x57214720 100; done ;;
  seeds)     for s in 0x1 0xDEADBEEF 0x12345678 0xCAFEF00D 0x0BADC0DE; do run seed_$s $s 100; done ;;
  fullrange) for s in 0x57214720 0xDEADBEEF 0x12345678; do run full_$s $s 65535; done ;;
  edge)      for p in allmax_allmin alt_extremes blocks ramps near_avg flat_then_step; do run edge_$p 0x57214720 65535 $p; done ;;
esac
