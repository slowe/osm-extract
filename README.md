# osm-extract
Extract layers from OSM.

Requires the following command line tools for the `update.pl` script to run:
  * `wget`
  * [`osmtools`](https://gitlab.com/osm-c-tools/osmctools) (`osmconvert`, [`osmfilter`](https://wiki.openstreetmap.org/wiki/Osmfilter#Download), `osmupdate`)
  * `ogr2ogr`

## Getting it working

Initially you'll need to create a config file e.g. `config-wy.json` that looks like this:
```
{
 "area": "great-britain/england/west-yorkshire",
	"pbf": "https://download.geofabrik.de/europe/great-britain/england/west-yorkshire-latest.osm.pbf",
	"updates": "download.geofabrik.de/europe/great-britain/england/west-yorkshire-updates",
	"temp": "temp/",
	"areas": {
		"horsforth": {
			"name": "Horsforth",
			"poly": "area-horsforth.poly",
			"layers": {
				"atm": {
					"keep": "amenity=atm"
				},
    "education": {
					"keep": "amenity=school =college =university",
					"drop": "barrier=gate =bollard entrance=yes"
				},
    ...
  }
 }
}
```

where each layer is defined by a `keep` and (optional) `drop`. Make sure `pbf` is set to the smallest appropriate area available from GeoFabrick to save the amount you need to download every day. You'll also need a [POLY file](https://wiki.openstreetmap.org/wiki/Osmosis/Polygon_Filter_File_Format) version of the boundary you want to extract.

On a daily basis you then run `perl update.pl config-wy.json` or whatever you called your config file. This downloads the PBF file from GeoFabrick then, for each defined layer, creates a GeoJSON extract using your `keep` and `drop` values. I've had to experiment to get appropriate things because there is a tendency for bollards, barriers, gates, and entrances to pass through if they are attached to certain things.

The result should be a bunch of GeoJSON files that can be used elsewhere.

## Command line commands

In case you hate perl or want to avoid it, you may want to re-implement this in your own preferred language. It may be useful to know some ways to invoke the OSM tools:

* `wget -q --no-check-certificate -O <LATEST PBF> "<PBF URL>"` - to get a copy of the PBF file
* `osmconvert <LATEST PBF> --out-timestamp` - should give you the time stamp of the data in the PBF file
* `osmconvert <LATEST PBF> -B=<POLY FILE> -o=<AREA EXTRACT>` - this will limit the PBF file to the boundary in our `<POLY FILE>`
* `osmfilter <AREA EXTRACT> --keep="<KEEP>" --drop="<DROP>" -o=<OUTPUT LAYER>` - to filter the `<AREA EXTRACT>` file with `<KEEP>` and `<DROP>` and save the output as a `.osm` file (`<OUTPUT LAYER>`).

This leaves you with a `.osm` file for a particular layer. You'll need to use `ogr2ogr` to extract the appropriate geometries as separate GeoJSON files and then combine them e.g. run

`ogr2ogr -overwrite --config OSM_CONFIG_FILE osmconf.ini -skipfailures -f GeoJSON <GEOJSON FILE FOR TYPE> <OUTPUT LAYER> <TYPE>`

for each `<TYPE>` ('points','lines','multilinestrings','multipolygons','other_relations'). You can then combine the GeoJSON contents into one GeoJSON file for this layer.
