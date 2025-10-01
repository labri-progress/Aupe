space="${1:-10}"

./bm.sh bm $space

./bm.sh merge $space 2000

./bm.sh merge $space 3000
