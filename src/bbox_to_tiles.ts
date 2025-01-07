export type Tile = [number, number, number];

const calculateTileRangeForBounds = (
  bounds: [number, number, number, number],
  zoom: number,
) => {
  const [minLon, minLat, maxLon, maxLat] = bounds;

  const convertCoordinatesToTiles = (
    lon: number,
    lat: number,
    zoom: number,
  ) => {
    const n = Math.pow(2, zoom);
    const x = Math.floor(((lon + 180) / 360) * n);
    const y = Math.floor(
      ((1 -
        Math.log(
          Math.tan((lat * Math.PI) / 180) + 1 / Math.cos((lat * Math.PI) / 180),
        ) /
          Math.PI) /
        2) *
        n,
    );
    return { x, y };
  };

  const { x: minX, y: maxY } = convertCoordinatesToTiles(minLon, minLat, zoom);
  const { x: maxX, y: minY } = convertCoordinatesToTiles(maxLon, maxLat, zoom);

  return { minX, minY, maxX, maxY };
};

function bboxToTiles(
  minx: number,
  miny: number,
  maxx: number,
  maxy: number,
  zoom: number,
): string {
  const bounds: [number, number, number, number] = [minx, miny, maxx, maxy];
  const { minX, minY, maxX, maxY } = calculateTileRangeForBounds(bounds, zoom);

  let tiles = "";
  for (let y = minY; y <= maxY; y++) {
    for (let x = minX; x <= maxX; x++) {
      tiles += `${zoom} ${x} ${y} `;
    }
  }
  return tiles;
}

const args = process.argv.slice(2);
const [minx, miny, maxx, maxy, zoom] = args;

console.log(
  bboxToTiles(
    Number(minx),
    Number(miny),
    Number(maxx),
    Number(maxy),
    Number(zoom),
  ),
);
