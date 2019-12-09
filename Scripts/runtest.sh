#!/bin/bash
for b in 11 12 
do
	for i in 40 42 44 46 
	do

		ns project_with_cbr.tcl $b 20 $i $i >> result
	done
done




