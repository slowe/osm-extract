DIR="$( cd "$( dirname "$0" )" && pwd )"

cd $DIR

git add "layers/horsforth/*.geojson"
git add LOG
git commit -m "Update Horsforth"
git push
git gc

