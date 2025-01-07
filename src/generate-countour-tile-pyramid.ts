import { Command } from "commander";
import { writeFileSync, mkdir } from "fs";
import { default as mlcontour } from "../node_modules/maplibre-contour/dist/index.mjs";
import { extractZXYFromUrlTrim, GetImageData, getOptionsForZoom } from "./mlcontour-adapter";
import { getPMtilesTile, openPMtiles,} from "./pmtiles-adapter";
import { getChildren } from "@mapbox/tilebelt";
import path from "path";
import type { Encoding } from "../node_modules/maplibre-contour/dist/types";
import { type PMTiles } from "pmtiles";
type Tile = [number, number, number];

const pmtilesTester = /^pmtiles:\/\//i;

const program = new Command();
program
  .name("generate-countour-tile-pyramid")
  .description(
    "Generates a pyramid of contour tiles from a source DEM using the mlcontour library.",
  )
  .requiredOption("--x <number>", "The X coordinate of the tile.")
  .requiredOption("--y <number>", "The Y coordinate of the tile.")
  .requiredOption("--z <number>", "The Z coordinate of the tile.")
  .requiredOption(
    "--demUrl <string>",
    "The URL of the DEM source (can be a PMTiles URL: 'pmtiles://...') or a regular tile URL pattern.",
  )
  .option(
    "--sEncoding <string>",
    "The encoding of the source DEM tiles (e.g., 'terrarium', 'mapbox').",
    (value) => {
      if (value !== "mapbox" && value !== "terrarium") {
        throw new Error(
          "Invalid value for --sEncoding, must be 'mapbox' or 'terrarium'",
        );
      }
      return value;
    },
    "mapbox", // default value
  )
  .option(
    "--sMaxZoom <number>",
    "The maximum zoom level of the source DEM.",
    "8", // default value as a string
  )
  .option(
    "--increment <number>",
    "The contour increment value to extract."
  )
  .option(
    "--oMaxZoom <number>",
    "The maximum zoom level of the output tile pyramid.",
    "8", // default value as a string
  )
  .requiredOption(
    "--oDir <string>",
    "The output directory where tiles will be stored.",
  )
  .parse(process.argv);

const options = program.opts();
const { x, y, z, demUrl, sEncoding, sMaxZoom, increment, oMaxZoom, oDir } =
  options;
const numX = Number(x);
const numY = Number(y);
const numZ = Number(z);
const numSMaxZoom = Number(sMaxZoom);
const numIncrement = Number(increment);
const numOMaxZoom = Number(oMaxZoom);

// --------------------------------------------------
// Functions
// --------------------------------------------------

function getAllTiles(tile: Tile, oMaxZoom: number): Tile[] {
    let allTiles: Tile[] = [tile];

    function getTileList(tile: Tile) {
        const children: Tile[] = getChildren(tile).filter(child => child[2] <= oMaxZoom);
        allTiles = allTiles.concat(children);
        for (const childTile of children) {
            const childZoom = childTile[2];
            if (childZoom < oMaxZoom) {
                getTileList(childTile);
            }
        }
    }

    getTileList(tile);
    return allTiles;
}

async function processTile(v: Tile): Promise<void> {
  const z: number = v[2];
  const x: number = v[0];
  const y: number = v[1];
  const dirPath: string = path.join(oDir, `${z}`, `${x}`);
  const filePath: string = path.join(dirPath, `${y}.pbf`);

  let tileOptions = contourOptions;
  if ("thresholds" in contourOptions) {
    tileOptions = getOptionsForZoom(contourOptions, z)
  }

  return manager
    .fetchContourTile(
      z,
      x,
      y,
      tileOptions,
      new AbortController(),
    )
    .then((tile) => {
      return new Promise<void>((resolve, reject) => {
        mkdir(dirPath, { recursive: true }, (err) => {
          if (err) {
            reject(err);
            return;
          }
          writeFileSync(filePath, Buffer.from(tile.arrayBuffer));
          resolve();
        });
      });
    });
}

async function processQueue(
  queue: Tile[],
  batchSize: number = 25,
): Promise<void> {
  for (let i = 0; i < queue.length; i += batchSize) {
    const batch = queue.slice(i, i + batchSize);
    console.log(
      `Processing batch ${i / batchSize + 1} of ${Math.ceil(queue.length / batchSize)} of tile ${z}/${x}/${y}`,
    );
    await Promise.all(batch.map(processTile));
    console.log(
      `Processed batch ${i / batchSize + 1} of ${Math.ceil(queue.length / batchSize)} of tile ${z}/${x}/${y}`,
    );
  }
}

// --------------------------------------------------
// mlcontour options/defaults
// --------------------------------------------------

const contourOptions = {
  multiplier: 1,
  ...(numIncrement ? { levels: [numIncrement] } : {
    thresholds: {
      1: 500,
      9: 100,
      11: 50,
      12: 10,
    }
  }),
  contourLayer: "contours",
  elevationKey: "ele",
  levelKey: "level",
  extent: 4096,
  buffer: 1,
};

const demManagerOptions = {
  cacheSize: 100,
  encoding: sEncoding as Encoding,
  maxzoom: numSMaxZoom,
  timeoutMs: 10000,
  decodeImage: GetImageData,
  ...(pmtilesTester.test(demUrl)
      ? {
          demUrlPattern: "/{z}/{x}/{y}",
          getTile: async (url: string, abortController: AbortController) => {
              if (!pmtiles) return;

              const $zxy = extractZXYFromUrlTrim(url);
              if (!$zxy) {
                  throw new Error(`Could not extract zxy from ${url}`);
              }

              const zxyTile = await getPMtilesTile(pmtiles, $zxy.z, $zxy.x, $zxy.y);
              if (!zxyTile || !zxyTile.data) {
                  throw new Error(`No tile returned for ${url}`);
              }

              const blob = new Blob([zxyTile.data]);
              return {
                  data: blob,
                  expires: undefined,
                  cacheControl: undefined,
              };
            },
        }
    : { demUrlPattern: demUrl }
  ),
};

// --------------------------------------------------
// Script
// --------------------------------------------------

let pmtiles: PMTiles;
if (pmtilesTester.test(demUrl)) {
    pmtiles = openPMtiles(demUrl.replace(pmtilesTester, ""));
}

const manager = new mlcontour.LocalDemManager(demManagerOptions)

// Use parsed command line args
const children: Tile[] = getAllTiles([numX, numY, numZ], numOMaxZoom);

children.sort((a, b) => {
  //Sort by Z first
  if (a[2] !== b[2]) return a[2] - b[2];
  //If Z is equal, sort by X
  if (a[0] !== b[0]) return a[0] - b[0];
  //If Z and X are equal, sort by Y
  return a[1] - b[1];
});

processQueue(children).then(() => {
  console.log(`All files for tile ${z}/${x}/${y} have been written!`);
});
