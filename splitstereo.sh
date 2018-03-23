#!/bin/bash

FILES=$@

for f in $FILES
do
echo "Processing $f"
echo "  - left -> l_${f}"
sox $f l_$f.wav remix 1
echo "  - right -> r_${f}"
sox $f r_$f.wav remix 2
done
