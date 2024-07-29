#!/bin/bash

#./rust.sh 1
machine="/etc/ansible/hosts" # "machines_g5k.txt" 
if [ ! -f "$machine" ]; then
    echo "Le fichier $machine n'existe pas."
    exit 1
fi

machines=()
while IFS= read -r line; do
    machines+=("$line")
    #ansible-playbook test.yml \
    #--extra-vars "node=$line target=$line ansible_user=root"
done < "$machine"

a=${#machines[@]}

numberofexpe=132
numberpermachine=$(echo "scale=0; $numberofexpe/10 / 1" | bc)
echo "array length $a and $numberpermachine processes"

copy_file="${1:-0}"

if [ $copy_file -eq 0 ]; then
    for element in "${machines[@]}"; do
        ansible-playbook playbook/rust_project_setup.yml \
        --extra-vars \
        "node=$element target=$element ansible_user=root"&
    done
fi

rep=1
if [ $copy_file -eq 1 ]; then # expe
  count=0
  while [ $count -lt $numberofexpe ];
  do 
    index=$(($count % $a))
    element=${machines[$index]}
    echo "-------["$element"] --> count"$count
    echo "-------["$element"] --> count"$count >> log.txt
    ansible-playbook playbook/expe.yml \
        --extra-vars \
        "node=$element target=$element ansible_user=root begin=$count rep=$rep end=$count" &
    
    let count=count+1
  done
fi

dir="/home/amukam/thss/simulation/Aupe"
if [ $copy_file -eq 2 ]; then # collect
  for element in "${machines[@]}"; do
    ansible-playbook playbook/collect_play.yml \
      --extra-vars \
      "node=$element target=$element ansible_user=root dir=$dir" &
  done 
fi

if [ $copy_file -eq 3 ]; then # clean
  for element in "${machines[@]}"; do
    ansible-playbook playbook/clean_play.yml \
      --extra-vars \
      "node=$element target=$element ansible_user=root" &
  done 
fi

if [ $copy_file -eq 4 ]; then #stop
  # Display the elements in the array
  echo "Elements read from the file:"
  for element in "${machines[@]}"; do
      echo "$element"
  done
  echo "array length $a and $numberpermachine processes"
fi