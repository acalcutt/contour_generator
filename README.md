# Contour Generator

Generates contour tiles in Mapbox Vector Tile (MVT) format from terrain raster-dem data using [maplibre-contour](https://github.com/onthegomap/maplibre-contour). It allows `maplibre-contour` to work with PMTiles (local or HTTP) when the `demUrl` is prefixed with `pmtiles://` and outputs to local MVT tiles.

This script outputs tile files in the ```<oDir>/z/x/y.pbf``` format and generates a ```<oDir>/metadata.json``` file. These files can be imported using [mbutil](https://github.com/mapbox/mbutil). For example, to import the tiles into an mbtiles file using mbutil, the syntax would be: ```python3 mb-util --image_format=pbf <oDir> output.mbtiles```.

# Install
```
apt-get install bc shfmt
npm install
```

# Script
generate_tiles.sh - Generates contour tiles based on specified function and parameters.
```
Usage: ./generate_tiles.sh <function> [options]

Functions:
 pyramid   generates contours for a parent tile and all child tiles up to a specified max zoom level.
 zoom      generates a list of parent tiles at a specifed zoom level, then runs pyramid on each of them in parallel
 bbox      generates a list of parent tiles that cover a bounding box, then runs pyramid on each of them in parallel

 General Options
  --demUrl <string>     The URL of the DEM source. (pmtiles://<http or local file path> or https://<zxyPattern>)
  --sEncoding <string>  The encoding of the source DEM tiles (e.g., 'terrarium', 'mapbox'). (default: mapbox)
  --sMaxZoom <number>   The maximum zoom level of the source DEM. (default: 8)
  --increment <number>  The contour increment value to extract. Use 0 for default thresholds.
  --oMaxZoom <number>   The maximum zoom level of the output tile pyramid. (default: 8)
  --oDir <string>       The output directory where tiles will be stored. (default: ./output)
  --processes <number>  The number of parallel processes to use. (default: 8)

 Additional Required Options for 'pyramid':
  --x <number>    The X coordinate of the parent tile.
  --y <number>    The Y coordinate of the parent tile.
  --z <number>    The Z coordinate of the parent tile.

 Additional Required Options for 'zoom':
  --oMinZoom <number>   The minimum zoom level of the output tile pyramid. (default: 5)

 Additional Required Options for 'bbox':
  --minx <number>   The minimum X coordinate of the bounding box.
  --miny <number>   The minimum Y coordinate of the bounding box.
  --maxx <number>   The maximum X coordinate of the bounding box.
  --maxy <number>   The maximum Y coordinate of the bounding box.
  --oMinZoom <number>   The minimum zoom level of the output tile pyramid. (default: 5)

  -v|--verbose  Enable verbose output
  -h|--help Show this usage statement
```
Usage Examples:

pyramid function (Generates tiles from a parent tile):
```
./generate_tiles.sh pyramid \
  --x 10 \
  --y 20 \
  --z 5 \
  --demUrl "pmtiles://path/to/your/dem.pmtiles" \
  --increment 50 \
  --oDir "./output_pyramid" \
   --oMaxZoom 10
```

zoom function (Generates tiles at and above a zoom level):
```
./generate_tiles.sh zoom \
  --demUrl "pmtiles://path/to/your/dem.pmtiles" \
  --oDir "./output_zoom" \
  --oMinZoom 8 \
  --increment 0 \
   --processes 10
```

bbox function (Generates tiles within a bounding box):
```
./generate_tiles.sh bbox \
  --minx -73.51 \
  --miny 41.23 \
  --maxx -69.93 \
  --maxy 42.88 \
  --demUrl "pmtiles://path/to/your/dem.pmtiles" \
  --oMinZoom 10 \
  --oDir "./output_bbox" \
    --increment 10 \
    -v
```

# Use with Docker
This image is published to Docker Hub as [wifidb/contour-generator](https://hub.docker.com/r/wifidb/contour-generator).

The docker image wifidb/contour-generator can be used for generating tiles in different ways

# Examples:

pyramid function (using Docker):
```
 docker run -it -v $(pwd):/data wifidb/contour-generator \
    pyramid \
    --x 10 \
    --y 20 \
    --z 5 \
    --demUrl "pmtiles:///data/raster-dem.pmtiles" \
    --oDir /data/output \
    --increment 50 \
    --oMaxZoom 8
```

zoom function (using Docker):
```
docker run -it -v $(pwd):/data wifidb/contour-generator \
    zoom \
    --demUrl "pmtiles:///data/raster-dem.pmtiles" \
    --oDir /data/output \
     --oMinZoom 5 \
     --oMinZoom 8 \
     --processes 8
```

bbox function (using Docker):
```
docker run -it -v $(pwd):/data wifidb/contour-generator \
    bbox \
    --minx -73.51 \
    --miny 41.23 \
    --maxx -69.93 \
    --maxy 42.88 \
    --demUrl "pmtiles:///data/raster-dem.pmtiles" \
    --oDir /data/output \
    --oMinZoom 10 \
    --increment 10 \
     -v
```

Building Dockerfile Locally
```
docker build -t contour-generator .
```

Important Notes:

The -v $(pwd):/data part of the docker run command maps your local working directory ($(pwd)) to /data inside the Docker container. Therefore, your DEM file must be located in the /data directory inside of the docker image, and the output directory must also be in the /data directory.
Replace the example pmtiles:///data/raster-dem.pmtiles with your actual file names, and output with your output name.
