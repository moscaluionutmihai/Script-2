#!/bin/bash

## Script Beta scris de Ionut Moscalu ##
##21.01.2013##


function DU {
du -sk * 2>/dev/null| awk ' { if (length($1) >= 6) print $2}'
}


## Sectiune in care cauta directoare ce au marime mai mare de 100M  ##
cd / ; $DU > /home/ionut/1.txt




## Sectiune in care cauta sa vada daca aceste directoare sunt montate in alta parte decat pe partitia /
## iar daca apar nu le mai afiseaza

for i in `cat /home/ionut/1.txt` 
	do 
	if [ -z "`df |grep $i`" ]; then
			echo $i>> /home/ionut/2.txt
			fi
	done

for a in `cat /home/ionut/2.txt`
	do
	cd \/$a; for b in `$DU`
		do 
			if [ -z `$DU` ];then
				cd \/$b;for c in `$DU`
					do 
						if [ -z `$DU` ];then
							cd \/$c;for d in `$DU`
							 do 
							pwd; `du -sk * 2>/dev/null| awk ' { if (length($1) >= 6) print }'
							else
							pwd; `du -sk * 2>/dev/null| awk ' { if (length($1) >= 6) print }'`
							fi
							done
					done
				else 
				pwd; `du -sk * 2>/dev/null| awk ' { if (length($1) >= 6) print }'`
			fi
		done
done
exit 0
