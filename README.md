# Contour Generator

Generates contour tiles in Mapbox Vector Tile (MVT) format from terrain raster-dem data using [maplibre-contour](https://github.com/onthegomap/maplibre-contour). It allows `maplibre-contour` to work with PMTiles (local or HTTP) when the `demUrl` is prefixed with `pmtiles://` and outputs to local MVT tiles.

This script outputs tile files in the ```<outputDir>/z/x/y.pbf``` format and generates a ```<outputDir>/metadata.json``` file. These files can be imported using [mbutil](https://github.com/mapbox/mbutil). For example, to import the tiles into an mbtiles file using mbutil, the syntax would be: ```python3 mb-util --image_format=pbf <outputDir> output.mbtiles```.

# Use with Docker
This image is published to Docker Hub as [wifidb/contour-generator](https://hub.docker.com/r/wifidb/contour-generator).

The docker image wifidb/contour-generator can be used for generating tiles in different ways

# Docker Examples:

pyramid function (using Docker w/pmtiles local source):
```
 wget https://github.com/acalcutt/contour_generator/releases/download/test_data/JAXA_2024_terrainrgb_z0-Z7_webp.pmtiles
 docker run -it -v $(pwd):/data wifidb/contour-generator \
    pyramid \
    --x 10 \
    --y 20 \
    --z 5 \
    --demUrl "pmtiles:///data/JAXA_2024_terrainrgb_z0-Z7_webp.pmtiles" \
    --encoding mapbox \
    --sourceMaxZoom 7 \
    --outputDir /data/output \
    --increment 50 \
    --outputMinZoom 4 \
    --outputMaxZoom 7 \
    -v
```

zoom function (using Docker w/pmtiles https source):
```
docker run -it -v $(pwd):/data wifidb/contour-generator \
    zoom \
    --demUrl "pmtiles://https://github.com/acalcutt/contour_generator/releases/download/test_data/JAXA_2024_terrainrgb_z0-Z7_webp.pmtiles" \
    --encoding mapbox \
    --outputDir /data/output \
    --sourceMaxZoom 7 \
    --outputMinZoom 5 \
    --outputMinZoom 7 \
    --processes 8 \
    -v
```

bbox function (using Docker w/zxyPattern source):
```
docker run -it -v $(pwd):/data wifidb/contour-generator \
    bbox \
    --minx -73.51 \
    --miny 41.23 \
    --maxx -69.93 \
    --maxy 42.88 \
    --demUrl "https://s3.amazonaws.com/elevation-tiles-prod/terrarium/{z}/{x}/{y}.png" \
    --encoding terrarium \
    --sourceMaxZoom 15 \
    --outputDir /data/output \
    --outputMinZoom 6 \
    --outputMinZoom 10 \
    --increment 0 \
    -v
```

Building Dockerfile Locally
```
docker build -t contour-generator .
```

Important Notes:

The -v $(pwd):/data part of the docker run command maps your local working directory ($(pwd)) to /data inside the Docker container. Therefore, your DEM file must be located in the /data directory inside of the docker image, and the output directory must also be in the /data directory.
Replace the example pmtiles:///data/raster-dem.pmtiles with your actual file names, and output with your output name.


# Install
```
apt-get install bc #Required for bash math functions
npm install
```

# Script
generate_tiles.sh - Generates contour tiles based on specified function and parameters.
```
Usage: ./generate_tiles.sh <function> [options]

Functions:
  pyramid    generates contours for a parent tile and all child tiles up to a specified max zoom level.
  zoom       generates a list of parent tiles at a specifed zoom level, then runs pyramid on each of them in parallel
  bbox       generates a list of parent tiles that cover a bounding box, then runs pyramid on each of them in parallel

General Options
  --demUrl <string>          The URL of the DEM source. (pmtiles://<http or local file path> or https://<zxyPattern>)
  --encoding <string>        The encoding of the source DEM tiles (e.g., 'terrarium', 'mapbox'). (default: mapbox)
  --sourceMaxZoom <number>   The maximum zoom level of the source DEM. (default: 8)
  --increment <number>       The contour increment value to extract. Use 0 for default thresholds.
  --outputMaxZoom <number>   The maximum zoom level of the output tile pyramid. (default: 8)
  --outputDir <string>       The output directory where tiles will be stored. (default: ./output)
  --processes <number>       The number of parallel processes to use. (default: 8)

Additional Required Options for 'pyramid':
  --x <number>               The X coordinate of the parent tile.
  --y <number>               The Y coordinate of the parent tile.
  --z <number>               The Z coordinate of the parent tile.

Additional Required Options for 'zoom':
  --outputMinZoom <number>   The minimum zoom level of the output tile pyramid. (default: 5)

Additional Required Options for 'bbox':
  --minx <number>            The minimum X coordinate of the bounding box.
  --miny <number>            The minimum Y coordinate of the bounding box.
  --maxx <number>            The maximum X coordinate of the bounding box.
  --maxy <number>            The maximum Y coordinate of the bounding box.
  --outputMinZoom <number>   The minimum zoom level of the output tile pyramid. (default: 5)

  -v|--verbose               Enable verbose output
  -h|--help                  Show this usage statement
```
Usage Examples:

pyramid function (Run Locally w/zxyPattern source):
```
./generate_tiles.sh pyramid \
  --x 10 \
  --y 20 \
  --z 5 \
  --demUrl "https://s3.amazonaws.com/elevation-tiles-prod/terrarium/{z}/{x}/{y}.png" \
  --encoding terrarium \
  --increment 50 \
  --outputDir "./output_pyramid" \
  --outputMaxZoom 10 \
  -v
```

zoom function (Run Locally w/pmtiles local source):
```
wget https://github.com/acalcutt/contour_generator/releases/download/test_data/JAXA_2024_terrainrgb_z0-Z7_webp.pmtiles
./generate_tiles.sh zoom \
  --demUrl "pmtiles://./JAXA_2024_terrainrgb_z0-Z7_webp.pmtiles" \
  --outputDir "./output_zoom" \
  --outputMinZoom 8 \
  --increment 0 \
   --processes 10 \
  -v
```

bbox function (Run Locally w/pmtiles https source):
```
./generate_tiles.sh bbox \
  --minx -73.51 \
  --miny 41.23 \
  --maxx -69.93 \
  --maxy 42.88 \
  --demUrl "pmtiles://https://github.com/acalcutt/contour_generator/releases/download/test_data/JAXA_2024_terrainrgb_z0-Z7_webp.pmtiles" \
  --outputMinZoom 10 \
  --outputDir "./output_bbox" \
  --increment 10 \
  -v
```
