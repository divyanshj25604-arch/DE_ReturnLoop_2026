#!/usr/bin/env bash
# Runs 30 workload queries with EXPLAIN (ANALYZE, BUFFERS)
# RUNS times (default 3), records execution times, and saves the raw plans.
#
# Usage:   ./benchmarks/run_benchmark.sh <database> <phase> [runs] [workload.sql]
# Examples:
#   ./benchmarks/run_benchmark.sh blinkit_db baseline
#   ./benchmarks/run_benchmark.sh blinkit_db optimized
#   ./benchmarks/run_benchmark.sh blinkit_db optimized 3 sql/06_optimized_queries.sql
#
# Connection settings come from standard libpq variables (PGHOST, PGPORT, PGUSER).
# Queries are split on "-- @R1" / "-- @W1" marker lines; "-- @END" stops collection.
# WRITE queries (W*) run inside BEGIN ... ROLLBACK for dataset idempotency.
set -euo pipefail

DB="${1:?database name required: e.g. ./benchmarks/run_benchmark.sh blinkit_db baseline}"
PHASE="${2:?phase required: e.g. baseline | optimized | large}"
RUNS="${3:-3}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Auto-select default workload based on benchmark phase if not explicitly passed
if [[ -n "${4:-}" ]]; then
  WORKLOAD="$4"
elif [[ "$PHASE" == "optimized" && -f "$ROOT/sql/06_optimized_queries.sql" ]]; then
  WORKLOAD="$ROOT/sql/06_optimized_queries.sql"
elif [[ "$PHASE" == "large" && -f "$ROOT/sql/08_partitioning.sql" ]]; then
  WORKLOAD="$ROOT/sql/08_partitioning.sql"
else
  WORKLOAD="$ROOT/queries/workload_30.sql"
fi

OUT="$ROOT/benchmarks/results/$PHASE"
SUMMARY="$OUT/summary.csv"

# Pre-flight environment and connection validation
command -v psql >/dev/null 2>&1 || { echo >&2 "Error: psql is not installed or not in PATH."; exit 1; }
if [[ ! -f "$WORKLOAD" ]]; then
  echo >&2 "Error: workload file not found: $WORKLOAD"
  exit 1
fi
if ! psql -d "$DB" -X -q -A -t -c "SELECT 1" >/dev/null 2>&1; then
  echo >&2 "Error: unable to connect to database '$DB'. Check database name and credentials."
  exit 1
fi

mkdir -p "$OUT"
echo "query_id,type,run1_ms,run2_ms,run3_ms,avg_ms,median_ms,min_ms,max_ms,scan_nodes" > "$SUMMARY"

# Split the workload file on "-- @ID" markers into one temp file per query
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT INT TERM

awk -v dir="$TMP" '
  /^[[:space:]]*--[[:space:]]*@/ {
    id = "";
    for (i = 1; i <= NF; i++) {
      if ($i ~ /^@[RW][0-9]+$/) {
        id = substr($i, 2);
        file = dir "/" id ".sql";
        printf "" > file;
        break;
      }
    }
    next;
  }
  id != "" && !/^[[:space:]]*--/ { print >> file }
' "$WORKLOAD"

# Verify that queries were successfully extracted
sql_files=($(find "$TMP" -maxdepth 1 -name "*.sql" | sort -V))
if [[ ${#sql_files[@]} -eq 0 ]]; then
  echo >&2 "Error: no valid query markers (-- @R01, -- @W01, etc.) found in $WORKLOAD."
  exit 1
fi

for f in "${sql_files[@]}"; do
  id="$(basename "$f" .sql)"
  type="READ"; [[ "$id" == W* ]] && type="WRITE"
  query="$(cat "$f")"
  
  # Strip trailing whitespace and semicolons to guarantee clean statement construction
  trimmed_query="$(printf '%s\n' "$query" | sed -e 's/[[:space:]]*;*[[:space:]]*$//')"
  if [[ -z "$trimmed_query" ]]; then
    continue
  fi

  times=()
  : > "$OUT/$id.txt"

  for ((i = 1; i <= RUNS; i++)); do
    if [[ "$type" == "WRITE" ]]; then
      sql="SET search_path TO blinkit, public; BEGIN; EXPLAIN (ANALYZE, BUFFERS) ${trimmed_query}; ROLLBACK;"
    else
      sql="SET search_path TO blinkit, public; EXPLAIN (ANALYZE, BUFFERS) ${trimmed_query};"
    fi

    plan="$(printf '%s\n' "$sql" | psql -d "$DB" -X -q -A -t -v ON_ERROR_STOP=1)"
    echo "=== $id run $i ===" >> "$OUT/$id.txt"
    echo "$plan" >> "$OUT/$id.txt"

    # Extract execution time reliably
    t="$(echo "$plan" | grep -oE 'Execution [tT]ime: [0-9.]+' | tail -n 1 | awk '{print $3}')"
    if [[ -z "$t" ]]; then
      echo >&2 "Error: could not extract Execution Time for $id on run $i."
      exit 1
    fi
    times+=("$t")
  done

  sorted=($(printf '%s\n' "${times[@]}" | sort -g))
  median="${sorted[$((RUNS / 2))]}"
  avg="$(printf '%s\n' "${times[@]}" | awk '{ s += $1 } END { printf "%.3f", s / NR }')"

  # Identify all scan nodes in the plan
  node="$(echo "$plan" | grep -oE '(Parallel )?(Seq Scan|Index Scan|Index Only Scan|Bitmap Heap Scan|Bitmap Index Scan|CTE Scan|Subquery Scan|Function Scan|Values Scan|Tid Scan)( Backward)?( using [a-zA-Z0-9_"]+)? on [a-zA-Z0-9_".]+' | sed -E 's/Parallel //; s/ Backward//' | awk '!seen[$0]++' | paste -sd'|' - | sed 's/|/ | /g' || true)"
  node="${node:-(no scan)}"

  r1="${times[0]:-}"
  r2="${times[1]:-}"
  r3="${times[2]:-}"
  echo "$id,$type,$r1,$r2,$r3,$avg,$median,${sorted[0]},${sorted[$((RUNS - 1))]},$node" >> "$SUMMARY"
  printf '%-4s %-5s avg %9s ms   %s\n' "$id" "$type" "$avg" "$node"
done

echo "Workload: $WORKLOAD"
echo "Saved raw plans and summary to $OUT"
