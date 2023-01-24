# osm-extract
Extract layers from OSM.

Requires the following command line tools for the `update.pl` script to run:
  * `wget`
  * [`osmtools`](https://gitlab.com/osm-c-tools/osmctools) (`osmconvert`, [`osmfilter`](https://wiki.openstreetmap.org/wiki/Osmfilter#Download), `osmupdate`)

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
where each layer is defined by a `keep` and (optional) `drop`. Make sure `pbf` is set to the smallest appropriate area available from GeoFabrick to save the amount you need to download every day. You'll also need a [POLY file](https://wiki.openstreetmap.org/wiki/Osmosis/Polygon_Filter_File_Format) version of the boundary you want to extract.

On a daily basis you then run `perl update.pl config-wy.json` or whatever you called your config file. This downloads the PBF file from GeoFabrick then, for each defined layer, creates a GeoJSON extract using your `keep` and `drop` values. I've had to experiment to get appropriate things because there is a tendency for bollards, barriers, gates, and entrances to pass through if they are attached to certain things.

The result should be a bunch of GeoJSON files that can be used elsewhere.
