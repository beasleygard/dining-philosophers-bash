philosopher_count=$1
pids=$@

function lock_cleanup() {
    rm -rf dining_philosophers.*.lock 2>&1
    rm -rf dining_philosophers.state_* 2>&1
}

function process_cleanup() {
    for pid in "${!pids[@]}"; do
        kill "$pid"
    done
}

function cleanup() {
    lock_cleanup
    process_cleanup
}

trap cleanup SIGINT

lock_cleanup

for i in $(seq 0 $((philosopher_count - 1))); do
    touch dining_philosophers.state_"$i"
done

for i in $(seq 0 $((philosopher_count - 1))); do
    printf "creating philosopher %s\n" $i
    ./philosopher.sh "$i" "$philosopher_count" &
    pids+=($!)
done

while true; do
    sleep 1
done
