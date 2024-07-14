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

copy_file="${1:-0}"

if [ $copy_file -eq 0 ]; then
    for element in "${machines[@]}"; do
        ansible-playbook playbook/rust_project_setup.yml \
        --extra-vars \
        "target=$element ansible_user=root"&
    done
fi

if [ $copy_file -eq 1 ]; then
    for element in "${machines[@]}"; do
        ansible-playbook playbook/expe.yml \
        --extra-vars \
        "target=$element ansible_user=root"&
    done
fi