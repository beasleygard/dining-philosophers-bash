#!/usr/bin/env bash

function lock_request() {
    local mutex=$1

    mkdir $mutex >/dev/null 2>&1
    acquired_lock=$?
    while [[ $acquired_lock != 0 ]]; do
        sleep 0.1
        mkdir $mutex >/dev/null 2>&1
        acquired_lock=$?
    done
}

function lock_release() {
    local mutex=$1
    rmdir $mutex >/dev/null 2>&1
}

function _enum() {
    local list=("$@")
    local len=${#list[@]}

    for ((i = 0; i < len; i++)); do
        eval "${list[i]}=$i"
    done
}

N=$2

STATES=(THINKING HUNGRY EATING) && _enum "${STATES[@]}"

function left() {
    return $((($1 - 1 + N) % N))
}

function right() {
    return $((($1 + 1 + N) % N))
}

crtical_region_mtx="./dining_philosophers.critical_region.lock" # mutex for critical regions for picking up and putting down forks
output_mtx="./dining_philosophers.output.lock"                  # for synchronized printing of THINKING/HUNGRY/EATING status

function my_rand() {
    local range=$(printf "%s-%s" "$1" "$2")
    func_result=$(shuf -i "$range" -n 1)
}

function test() {
    local self_state=$(<dining_philosophers.state_"$1")
    left $1
    local left_state=$(<dining_philosophers.state_"$?")
    right $1
    local right_state=$(<dining_philosophers.state_"$?")

    if [[ $self_state = "$HUNGRY" ]] && [[ $left_state != "$EATING" ]] && [[ $right_state != "$EATING" ]]; then
        echo $EATING >dining_philosophers.state_"$1"
        lock_release dining_philosophers.fork_"$1".lock
        return 1
    fi
    return 0
}

function think() {
    local i=$1
    my_rand 400 800
    local duration=$func_result
    lock_request $output_mtx
    printf "%s is THINKING %sms\n" "$i" "$duration" # >>output.txt
    lock_release $output_mtx
    sleep 0."$duration"
}

function take_forks() {
    local i=$1
    lock_request $crtical_region_mtx
    echo $HUNGRY >dining_philosophers.state_"$i"
    lock_request $output_mtx
    printf "%s is HUNGRY\n" "$i"
    lock_release $output_mtx
    test "$i" #try to acquire a permit for 2 forks
    lock_release $crtical_region_mtx
    lock_request dining_philosophers.fork_"$1".lock
}

function eat() {
    local i=$i

    my_rand 400 800
    local duration=$func_result
    lock_request $output_mtx
    printf "%s is EATING %sms\n" "$i" "$duration"
    lock_release $output_mtx
    sleep 0."$duration"
}

function put_forks() {
    local i=$i
    left "$i"
    local left=$?
    right "$i"
    local right=$?

    lock_request $crtical_region_mtx
    echo "$THINKING" >dining_philosophers.state_"$i"
    test $left
    test $right
    lock_release $crtical_region_mtx
}

function philosopher() {
    local i=$1
    while true; do
        think "$i"      # philosopher is THINKING
        take_forks "$i" # acquire two forks or block
        eat "$i"        # eat spaghetti
        put_forks "$i"  # put both forks back on table and check if neighbours can eat
    done
}

philosopher "$1"
