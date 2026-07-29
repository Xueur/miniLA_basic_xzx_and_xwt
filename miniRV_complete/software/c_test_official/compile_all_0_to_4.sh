#!/bin/sh
set -eu

root_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

for test_name in 0_uart_test 1_formatIO_test 2_sort_test 3_ddr_test
do
    echo "Compiling $test_name"
    (
        cd "$root_dir/$test_name"
        chmod +x compile.sh
        ./compile.sh
    )
done

echo "Compiling 4_coremark"
(
    cd "$root_dir/4_coremark"
    make clean
    make
)

echo "C_TEST 0 through 4 compiled."
