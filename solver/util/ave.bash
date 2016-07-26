#!/bin/bash
code=$1
n=$2
rm tmp.txt
for ((i = 0; i< 12; i++))
do
	ruby solve.rb "../csp/ise${code}.csp" "../reading/reading${code}.txt" ${n}>> tmp.txt 
done