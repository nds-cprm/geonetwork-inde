
 NET=$1

 docker inspect $NET | \
 grep -E '"Name":|"IPv4Address":' | \
 sed -e '1d; s/"[^:]*: "//; s/",$//; s/\/20//; s/\n\t\d/\t/; s/ //g; ' | \
 sed -e 'N; s/\n/ /; s/\([^ ]*\) \([^ ]*\)/\2 \1/;'
