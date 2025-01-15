import { spawn } from 'child_process';
import path from 'path';
import minimist from 'minimist';
import { writeFileSync } from 'fs';
import { bboxToTiles } from './bbox_to_tiles';

type BaseOptions = {
    demUrl: string;
    encoding: 'mapbox' | 'terrarium';
    sourceMaxZoom: number;
    increment: number;
    outputMaxZoom: number;
    outputDir: string;
    processes: number;
    verbose: boolean;
}

// Default configuration
const CONFIG: BaseOptions & { outputMinZoom: number } = {
    demUrl: "",
    verbose: false,
    increment: 0,
    sourceMaxZoom: 8,
    encoding: 'mapbox',
    outputMaxZoom: 8,
    outputMinZoom: 5,
    outputDir: './output',
    processes: 8
};


type PyramidOptions = BaseOptions & {
    x: number;
    y: number;
    z: number;
}

type ZoomOptions = BaseOptions & {
    outputMinZoom: number;
}

type BboxOptions = BaseOptions & {
    minx: number;
    miny: number;
    maxx: number;
    maxy: number;
    outputMinZoom: number;
}

/**
 * Helper function to print usage information
 */
function printUsage(): void {
    console.log(`
Usage: contour-generator <function> [options]

Functions:
  pyramid    generates contours for a parent tile and all child tiles up to a specified max zoom level.
  zoom       generates a list of parent tiles at a specifed zoom level, then runs pyramid on each of them in parallel
  bbox       generates a list of parent tiles that cover a bounding box, then runs pyramid on each of them in parallel

General Options:
  --demUrl <string>          The URL of the DEM source. (pmtiles://<http or local file path> or https://<zxyPattern>)
  --encoding <string>        The encoding of the source DEM (e.g., 'terrarium', 'mapbox'). (default: ${CONFIG.encoding})
  --sourceMaxZoom <number>   The maximum zoom level of the source DEM. (default: ${CONFIG.sourceMaxZoom})
  --increment <number>       The contour increment value to extract. Use 0 for default thresholds.
  --outputMaxZoom <number>   The maximum zoom level of the output tile pyramid. (default: ${CONFIG.outputMaxZoom})
  --outputDir <string>       The output directory where tiles will be stored. (default: ${CONFIG.outputDir})
  --processes <number>       The number of parallel processes to use. (default: ${CONFIG.processes})

Additional Required Options for 'pyramid':
  --x <number>               The X coordinate of the parent tile.
  --y <number>               The Y coordinate of the parent tile.
  --z <number>               The Z coordinate of the parent tile.

Additional Required Options for 'zoom' and 'bbox':
  --outputMinZoom <number>   The minimum zoom level of the output tile pyramid. (default: ${CONFIG.outputMinZoom})

Additional Required Options for 'bbox':
  --minx <number>            The minimum X coordinate of the bounding box.
  --miny <number>            The minimum Y coordinate of the bounding box.
  --maxx <number>            The maximum X coordinate of the bounding box.
  --maxy <number>            The maximum Y coordinate of the bounding box.

  -v, --verbose             Enable verbose output
  -h, --help               Show this usage statement
`);
}

/**
 * Helper function to validate encoding
 * @param encoding - The encoding to validate
 */
function validateEncoding(encoding: string): asserts encoding is 'mapbox' | 'terrarium' {
    if (encoding !== 'mapbox' && encoding !== 'terrarium') {
        throw new Error('Encoding must be either "mapbox" or "terrarium"');
    }
}
/**
 * Function to generate tile coordinates
 * @param zoomLevel - The zoom level to generate coordinates for
 * @returns 
 */
function generateTileCoordinates(zoomLevel: number): Array<[number, number, number]> {
    const tilesInDimension = Math.pow(2, zoomLevel);
    const coordinates: Array<[number, number, number]> = [];

    for (let y = 0; y < tilesInDimension; y++) {
        for (let x = 0; x < tilesInDimension; x++) {
            coordinates.push([zoomLevel, x, y]);
        }
    }

    return coordinates;
}

// Function to create metadata.json
async function createMetadata(outputDir: string, outputMinZoom: number, outputMaxZoom: number): Promise<void> {
    const metadata = {
        name: `Contour_z${outputMinZoom}_Z${outputMaxZoom}`,
        type: 'baselayer',
        description: new Date().toISOString(),
        version: '1',
        format: 'pbf',
        minzoom: outputMinZoom.toString(),
        maxzoom: outputMaxZoom.toString(),
        json: JSON.stringify({
            vector_layers: [{
                id: 'contours',
                fields: {
                    ele: 'Number',
                    level: 'Number'
                },
                minzoom: outputMinZoom,
                maxzoom: outputMaxZoom
            }]
        }),
        bounds: '-180.000000,-85.051129,180.000000,85.051129'
    };

    writeFileSync(path.join(outputDir, 'metadata.json'), JSON.stringify(metadata, null, 2));
    console.log(`metadata.json has been created in ${outputDir}`);
}

/**
 * Function to process a single tile
 * @param options - The options for processing the tile
 * @returns 
 */
async function processTile(options: PyramidOptions): Promise<void> {
    if (options.verbose) {
        console.log(`Processing tile - Zoom: ${options.z}, X: ${options.x}, Y: ${options.y}, outputMaxZoom: ${options.outputMaxZoom}`);
    }

    validateEncoding(options.encoding);

    return new Promise((resolve, reject) => {
        const process = spawn('npm', [
            'run',
            'generate-contour-tile-pyramid',
            '--',
            '--x', options.x.toString(),
            '--y', options.y.toString(),
            '--z', options.z.toString(),
            '--demUrl', options.demUrl,
            '--encoding', options.encoding,
            '--sourceMaxZoom', options.sourceMaxZoom.toString(),
            '--increment', options.increment.toString(),
            '--outputMaxZoom', options.outputMaxZoom.toString(),
            '--outputDir', options.outputDir
        ]);

        if (options.verbose) {
            process.stdout.on('data', (data) => {
                console.log(data.toString().trim());
            });
        }

        process.on('close', (code) => {
            if (code === 0) {
                if (options.verbose) {
                    console.log(`Finished processing ${options.z}-${options.x}-${options.y}`);
                }
                resolve();
            } else {
                console.log(process)
                reject(new Error(`Process exited with code ${code}`));
            }
        });
    });
}
/**
 * Function to process tiles in parallel
 * @param coordinates 
 * @param options 
 * @param processes 
 */
async function processTilesInParallel(
    coordinates: Array<[number, number, number]>,
    options: BaseOptions,
    processes: number
): Promise<void> {
    const chunks = coordinates.reduce((acc, curr, i) => {
        const chunkIndex = i % processes;
        acc[chunkIndex] = acc[chunkIndex] || [];
        acc[chunkIndex].push(curr);
        return acc;
    }, [] as Array<Array<[number, number, number]>>);

    await Promise.all(chunks.map(chunk =>
        Promise.all(chunk.map(([z, x, y]) =>
            processTile({
                ...options,
                x,
                y,
                z
            })
        ))
    ));
}


async function runPyramid(options: Required<PyramidOptions>): Promise<void> {
    await processTile(options);
    await createMetadata(options.outputDir, options.z, options.outputMaxZoom);
}

async function runZoom(options: ZoomOptions): Promise<void> {
    options.outputMinZoom = options.outputMinZoom || CONFIG.outputMinZoom;
    if (options.verbose) {
        console.log('Source File:', options.demUrl);
        console.log('Output Directory:', options.outputDir);
        console.log('Output Min Zoom:', options.outputMinZoom);
        console.log('Output Max Zoom:', options.outputMaxZoom);
        console.log('Main: [START] Processing tiles.');
    }

    const coordinates = generateTileCoordinates(options.outputMinZoom);
    await processTilesInParallel(coordinates, options, options.processes);
    
    if (options.verbose) {
        console.log(`Main: [END] Finished processing all tiles at zoom level ${options.outputMinZoom}.`);
    }

    await createMetadata(options.outputDir, options.outputMinZoom, options.outputMaxZoom);
}

async function runBbox(options: BboxOptions): Promise<void> {
    options.outputMinZoom = options.outputMinZoom || CONFIG.outputMinZoom;
    const coordinates = await bboxToTiles(options.minx, options.miny, options.maxx, options.maxy, options.outputMinZoom);

    if (options.verbose) {
        console.log('Source File:', options.demUrl);
        console.log('Output Directory:', options.outputDir);
        console.log('Bounding Box:', `${options.minx},${options.miny},${options.maxx},${options.maxy}`);
        console.log('Main: [START] Processing tiles.');
    }

    await processTilesInParallel(coordinates, options, options.processes);

    if (options.verbose) {
        console.log('Main: [END] Finished processing all tiles in bounding box.');
    }

    await createMetadata(options.outputDir, options.outputMinZoom, options.outputMaxZoom);
}

async function runCommand(command: string, argv: any): Promise<void> {
    try {
        const options: BaseOptions = argv;
        if (!options.demUrl) {
            throw new Error('Missing required parameter: demUrl');
        }
        options.encoding = options.encoding || CONFIG.encoding;
        options.sourceMaxZoom = options.sourceMaxZoom || CONFIG.sourceMaxZoom;
        options.increment = options.increment || CONFIG.increment;
        options.outputMaxZoom = options.outputMaxZoom || CONFIG.outputMaxZoom;
        options.outputDir = options.outputDir || CONFIG.outputDir;
        options.processes = options.processes || CONFIG.processes;
        options.verbose = options.verbose || CONFIG.verbose;


        switch (command) {
            case 'pyramid': {
                const required = ['x', 'y', 'z'];
                const missing = required.filter(param => argv[param] === undefined);
                if (missing.length > 0) {
                    throw new Error(`Missing required parameters for pyramid: ${missing.join(', ')}`);
                }
                await runPyramid(options as PyramidOptions);
                break;
            }
            case 'zoom': {
                await runZoom(options as ZoomOptions);
                break;
            }
            case 'bbox': {
                const required = ['minx', 'miny', 'maxx', 'maxy'];
                const missing = required.filter(param => argv[param] === undefined);
                if (missing.length > 0) {
                    throw new Error(`Missing required parameters for bbox: ${missing.join(', ')}`);
                }
                await runBbox(options as BboxOptions);
                break;
            }
            default:
                throw new Error(`Unknown command: ${command}`);
        }
    } catch (error) {
        console.error('Error:', error.message);
        process.exit(1);
    }
}

/**
 * Main flow
 */
const argv = minimist(process.argv.slice(2), {
    string: ['demUrl', 'encoding', 'outputDir'],
    number: ['x', 'y', 'z', 'sourceMaxZoom', 'increment', 'outputMaxZoom', 
            'outputMinZoom', 'processes', 'minx', 'miny', 'maxx', 'maxy'],
    boolean: ['verbose', 'help'],
    alias: {
        v: 'verbose',
        h: 'help'
    },
    default: {
        ...CONFIG
    }
});

if (argv.help || argv._.length === 0) {
    printUsage();
    process.exit(argv.help ? 0 : 1);
}

const command = argv._[0];

runCommand(command, argv);