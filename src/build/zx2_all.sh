for i in "${1}"*_*;
do
	if [[ $i != *.sapr && $i != *.zx2 ]]
	then
		#./zx2 -f "$i" "$i.zx2_default";
		#./zx2 -f -y "$i" "$i.zx2_limited";
		./zx2 -f "$i" "$i.zx2";
	fi
done
