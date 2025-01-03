# Contour Generator

Generates contour tiles in mapbox vector format using a maplibre-contour. It allows maplibre-contour to work with pmtiles (local or http) when the demUrl is prefixed with 'pmtiles://' and outputs to local mvt tiles.

This outputs files in the <oDir>/z/x/y.pbf format, which can be impoted with mbutil. Note an example metadata.json file has been included which can be placed in the <oDir> directory and edited before using mbutil.

# Install
```
npm isntall
```

# Scripts

src/generate-countour-tile-pyramid.ts - Generates all child tiles from a specified parent tile up to a specified zoom level

```
Useage: npx tsx ./src/generate-countour-tile-pyramid.ts --x <tile x> --y <tile y> --z <tile z> --demUrl [options]
Options:
  --x <number>          The X coordinate of the tile.
  --y <number>          The Y coordinate of the tile.
  --z <number>          The Z coordinate of the tile.
  --demUrl <string>     The URL of the DEM source (can be a PMTiles URL: 'pmtiles://...') or a regular tile URL
                        pattern.
  --sEncoding <string>  The encoding of the source DEM tiles (e.g., 'terrarium', 'mapbox'). (default: "mapbox")
  --sMaxZoom <number>   The maximum zoom level of the source DEM. (default: "8")
  --increment <number>  The contour increment value to extract.
  --oMaxZoom <number>   The maximum zoom level of the output tile pyramid. (default: "8")
  --oDir <string>       The output directory where tiles will be stored.
  -h, --help            display help for command
  ```

generate_all_tiles_at_zoom.sh - Gets all tiles at a specified zoom level, then runs generate-countour-tile-pyramid.ts for them all in parrallel.
```
Usage: ./generate_all_tiles_at_zoom.sh --demUrl <path> [options]
 Options:
  --increment <value> Increment value (default: 0)
  --sMaxZoom <value> Source Max Zoom (default: 8)
  --sEncoding <encoding> Source Encoding (default: mapbox) (must be 'mapbox' or 'terrarium')
  --demUrl <path>  TerrainRGB or Terrarium PMTiles File Path or URL (REQUIRED)
  --oDir <path>  Output Directory (default: ./output)
  --oMaxZoom <value> Output Max Zoom (default: 8)
  --oMinZoom <value> Output Min Zoom (default: 5)
  -v|--verbose  Enable verbose output
  -h|--help  Show this usage statement
```
