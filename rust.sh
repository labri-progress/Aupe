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
echo "array length $a"
numberofexpe=100

copy_file="${1:-0}"

if [ $copy_file -eq 0 ]; then
    for element in "${machines[@]}"; do
        ansible-playbook playbook/rust_project_setup.yml \
        --extra-vars \
        "target=$element ansible_user=root"&
    done
fi

rep=1
if [ $copy_file -eq 1 ]; then # expe
  count=0
  while [ $count -le $numberofexpe ];
  do 
    index=$(($count % $a))
    element=${machines[$index]}
    let end=count+10
    echo "-------["$element"] --> count"$count
    echo "-------["$element"] --> count"$count >> log.txt
    ansible-playbook playbook/expe.yml \
        --extra-vars \
        "target=$element ansible_user=root begin=$count rep=$rep end=$end" &
    
    let count=end
  done
fi

dir="/home/amukam/thss/simulation/Aupe"
if [ $copy_file -eq 2 ]; then # collect
  for element in "${machines[@]}"; do
    ansible-playbook playbook/collect_play.yml \
      --extra-vars \
      "target=$element ansible_user=root dir=$dir" &
  done 
fi

if [ $copy_file -eq 3 ]; then # collect
  for element in "${machines[@]}"; do
    ansible-playbook playbook/clean_play.yml \
      --extra-vars \
      "target=$element ansible_user=root" &
  done 
fi