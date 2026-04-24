#!/bin/bash

echo never > /sys/kernel/mm/transparent_hugepage/hugepages-64kB/enabled
echo never > /sys/kernel/mm/transparent_hugepage/hugepages-32kB/enabled
echo never > /sys/kernel/mm/transparent_hugepage/hugepages-16kB/enabled
echo never > /sys/kernel/mm/transparent_hugepage/hugepages-2048kB/enabled

vmstat_path="/proc/vmstat"
thp_base_path="/sys/kernel/mm/transparent_hugepage"

read_values() {
    pswpin=$(grep "pswpin" $vmstat_path | awk '{print $2}')
    pswpout=$(grep "pswpout" $vmstat_path | awk '{print $2}')
    pgpgin=$(grep "pgpgin" $vmstat_path | awk '{print $2}')
    pgpgout=$(grep "pgpgout" $vmstat_path | awk '{print $2}')
    swpout_zero=$(grep "swpout_zero" $vmstat_path | awk '{print $2}')
    swpin_zero=$(grep "swpin_zero" $vmstat_path | awk '{print $2}')
    swpout_64k=$(cat $thp_base_path/hugepages-64kB/stats/swpout 2>/dev/null || echo 0)
    swpout_32k=$(cat $thp_base_path/hugepages-32kB/stats/swpout 2>/dev/null || echo 0)
    swpout_16k=$(cat $thp_base_path/hugepages-16kB/stats/swpout 2>/dev/null || echo 0)
    
    swpin_64k=$(cat $thp_base_path/hugepages-64kB/stats/swpin 2>/dev/null || echo 0)
    swpin_32k=$(cat $thp_base_path/hugepages-32kB/stats/swpin 2>/dev/null || echo 0)
    swpin_16k=$(cat $thp_base_path/hugepages-16kB/stats/swpin 2>/dev/null || echo 0)
    refault_file=$(grep "workingset_refault_file" $vmstat_path | awk '{print $2}')
    refault_anon=$(grep "workingset_refault_anon" $vmstat_path | awk '{print $2}')
   
    echo "$pswpin $pswpout $swpout_64k $swpout_32k $swpout_16k $swpin_64k $swpin_32k $swpin_16k $pgpgin $pgpgout $swpout_zero $swpin_zero $refault_file $refault_anon"
}

for ((i=1; i<=5; i++))
do
  echo
  echo "*** Executing round $i ***"
  swappiness=$((i * 35))
  echo $swappiness > /proc/sys/vm/swappiness
  echo "set swappiness to $swappiness"
  make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- clean 1>/dev/null 2>/dev/null
  echo 3 > /proc/sys/vm/drop_caches

  #kernel build
  initial_values=($(read_values))
  time systemd-run --scope -p MemoryMax=1G make ARCH=arm64 \
        CROSS_COMPILE=aarch64-linux-gnu- vmlinux -j20 1>/dev/null 2>/dev/null
  final_values=($(read_values))

  echo "pswpin: $((final_values[0] - initial_values[0]))"
  echo "pswpout: $((final_values[1] - initial_values[1]))"
  #echo "64kB-swpout: $((final_values[2] - initial_values[2]))"
  #echo "32kB-swpout: $((final_values[3] - initial_values[3]))"
  #echo "16kB-swpout: $((final_values[4] - initial_values[4]))"
  #echo "64kB-swpin: $((final_values[5] - initial_values[5]))"
  #echo "32kB-swpin: $((final_values[6] - initial_values[6]))"
  #echo "16kB-swpin: $((final_values[7] - initial_values[7]))"
  echo "pgpgin: $((final_values[8] - initial_values[8]))"
  echo "pgpgout: $((final_values[9] - initial_values[9]))"
  echo "swpout_zero: $((final_values[10] - initial_values[10]))"
  echo "swpin_zero: $((final_values[11] - initial_values[11]))"
  echo "refault_file: $((final_values[12] - initial_values[12]))"
  echo "refault_anon: $((final_values[13] - initial_values[13]))"
  sync
  sleep 10
done
