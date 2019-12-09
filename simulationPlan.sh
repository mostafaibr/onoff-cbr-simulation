for m in 20 40 60
do
	for i in 13 14 15 16 17 18 19 20
	do
   		for j in 30 31 32 33 34 35 36 37 38 39 40 41 42 43 44 45 46 47 48 49 50 55 60 65 70 75 80 90 100 110 
		do
   			ns project.tcl $i $m $j $j >>lambda${m}b$i.tr
		done
	done
done

