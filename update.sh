cd /mnt/Trifle/osm-extract/

perl update.pl

git add layers/horsforth/*.geojson
git commit -m "Update Horsforth"
git push
git gc
