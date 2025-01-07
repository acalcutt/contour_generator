#!/bin/bash

# Default Values (except demUrl and oDir)
increment_default=0
sMaxZoom_default=8
sEncoding_default="mapbox"
oMaxZoom_default=8
oMinZoom_default=5
oDir_default=./output

usage() {
    echo "Usage: $0 <function> [options]" >&2
    echo " Options for function generate-tile-pyramid:" >&2
    echo "  --x <number>          The X coordinate of the parent tile." >&2
    echo "  --y <number>          The Y coordinate of the parent tile." >&2
    echo "  --z <number>          The Z coordinate of the parent tile." >&2
    echo "  --demUrl <string>     The URL of the DEM source. (pmtiles://<http or local file path> or https://<zxyPattern>)" >&2
    echo "  --sEncoding <string>  The encoding of the source DEM tiles (e.g., 'terrarium', 'mapbox'). (default: $sEncoding_default)" >&2
    echo "  --sMaxZoom <number>   The maximum zoom level of the source DEM. (default: $sMaxZoom_default)" >&2
    echo "  --increment <number>  The contour increment value to extract." >&2
    echo "  --oMaxZoom <number>   The maximum zoom level of the output tile pyramid. (default: $oMaxZoom_default)" >&2
    echo "  --oDir <string>       The output directory where tiles will be stored. (default: $oDir_default)" >&2
    echo "" >&2
    echo "Options for function generate-zoom-level:" >&2
    echo "  --increment <number>  The contour increment value to extract. (default: $increment_default)" >&2
    echo "  --sMaxZoom <number>   The maximum zoom level of the source DEM. (default: $sMaxZoom_default)" >&2
    echo "  --sEncoding <string>  The encoding of the source DEM tiles (e.g., 'terrarium', 'mapbox'). (default: $sEncoding_default)" >&2
    echo "  --demUrl <string>     The URL of the DEM source. (pmtiles://<http or local file path> or https://<zxyPattern>)" >&2
    echo "  --oDir <string>       The output directory where tiles will be stored. (default: $oDir_default)" >&2
    echo "  --oMaxZoom <number>   The maximum zoom level of the output tile pyramid. (default: $oMaxZoom_default)" >&2
    echo "  --oMinZoom <number>   The minimum zoom level of the output tile pyramid. (default: $oMinZoom_default)" >&2
    echo "" >&2
    echo "  -v|--verbose  Enable verbose output" >&2
    echo "  -h|--help  Show this usage statement" >&2
    echo "" >&2
    echo "Functions:" >&2
    echo "  generate-tile-pyramid" >&2
    echo "  generate-zoom-level" >&2
}

# Function to parse command line arguments for function generate-tile-pyramid
parse_arguments_option_1() {
    local x=""
    local y=""
    local z=""
    local demUrl=""
    local sEncoding="$sEncoding_default"
    local sMaxZoom="$sMaxZoom_default"
    local increment=""
    local oMaxZoom="$oMaxZoom_default"
    local oDir="$oDir_default"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --x) x="$2"; shift 2;;
            --y) y="$2"; shift 2;;
            --z) z="$2"; shift 2;;
            --demUrl) demUrl="$2"; shift 2;;
            --sEncoding) sEncoding="$2"; shift 2;;
            --sMaxZoom) sMaxZoom="$2"; shift 2;;
            --increment) increment="$2"; shift 2;;
            --oMaxZoom) oMaxZoom="$2"; shift 2;;
            --oDir) oDir="$2"; shift 2;;
            -h|--help) usage; exit 1;;
            *) echo "Unknown option: $1" >&2; usage; exit 1;;
        esac
    done

    # Check if all required values are provided
    if [[ -z "$x" || -z "$y" || -z "$z" || -z "$demUrl" || -z "$increment" ]]; then
        echo "Error: --x, --y, --z, --demUrl, and --increment are required for function generate-tile-pyramid." >&2
        usage
        exit 1
    fi

    # check for valid sEncoding
    if [[ "$sEncoding" != "mapbox" && "$sEncoding" != "terrarium" ]]; then
        echo "Error: --sEncoding must be either 'mapbox' or 'terrarium'." >&2
        usage
        exit 1 # Return non-zero on error
    fi

    echo "$x $y $z $demUrl $sEncoding $sMaxZoom $increment $oMaxZoom $oDir"
    return 0
}

# Function to parse command line arguments for function generate-zoom-level
parse_arguments_option_2() {
    local verbose=false
    local demUrl=""
    local oDir="$oDir_default"
    local increment="$increment_default"
    local sMaxZoom="$sMaxZoom_default"
    local sEncoding="$sEncoding_default"
    local oMaxZoom="$oMaxZoom_default"
    local oMinZoom="$oMinZoom_default"

    while [[ $# -gt 0 ]]; do
        case "$1" in
        -h|--help) usage; exit 1;; # Show usage and exit
        --increment) increment="$2"; shift 2 ;;
        --sMaxZoom) sMaxZoom="$2"; shift 2 ;;
        --sEncoding) sEncoding="$2"; shift 2 ;;
        --demUrl) demUrl="$2"; shift 2 ;;
        --oDir) oDir="$2"; shift 2 ;;
        --oMaxZoom) oMaxZoom="$2"; shift 2 ;;
        --oMinZoom) oMinZoom="$2"; shift 2 ;;		
        -v|--verbose) verbose=true; shift ;;
        *) echo "Unknown option: $1" >&2; usage; exit 1;; # Return non-zero on error
        esac
    done

    # Check if demUrl and oDir are provided
    if [[ -z "$demUrl" ]]; then
        echo "Error: --demUrl is required." >&2
        usage
        exit 1 # Return non-zero on error
    fi

    # Check if sEncoding is valid
    if [[ "$sEncoding" != "mapbox" && "$sEncoding" != "terrarium" ]]; then
        echo "Error: --sEncoding must be either 'mapbox' or 'terrarium'." >&2
        usage
        exit 1 # Return non-zero on error
    fi

    # Return the values as a single string
    echo "$oMinZoom $demUrl $oDir $increment $sMaxZoom $sEncoding $oMaxZoom $verbose"
    return 0 # return zero for success
}

# Function 1: Generate all tiles under parent tile
run_option_1() {
    local programOptions="$1"
    read x y z demUrl sEncoding sMaxZoom increment oMaxZoom oDir <<<"$programOptions"

    echo "Executing Function 1: npx tsx ./src/generate-countour-tile-pyramid.ts --x $x --y $y --z $z --demUrl $demUrl --sEncoding $sEncoding --sMaxZoom $sMaxZoom --increment $increment --oMaxZoom $oMaxZoom --oDir $oDir"
    npx tsx ./src/generate-countour-tile-pyramid.ts --x "$x" --y "$y" --z "$z" --demUrl "$demUrl" --sEncoding "$sEncoding" --sMaxZoom "$sMaxZoom" --increment "$increment" --oMaxZoom "$oMaxZoom" --oDir "$oDir"
}

# Function 2: Generate all tiles at and above zoom level
process_tile() {
    local programOptions="$0"
    local zoom_level="$1"
    local x_coord="$2"
    local y_coord="$3"
 

    read oMinZoom demUrl oDir increment sMaxZoom sEncoding oMaxZoom verbose <<<"$programOptions"

    if [[ "$verbose" = "true" ]]; then
        echo "process_tile: [START] Processing tile - Zoom: $zoom_level, X: $x_coord, Y: $y_coord, oMaxZoom: $oMaxZoom"
    fi

    npx tsx ./src/generate-countour-tile-pyramid.ts \
        --x "$x_coord" \
        --y "$y_coord" \
        --z "$zoom_level" \
        --demUrl "$demUrl" \
        --sEncoding "$sEncoding" \
        --sMaxZoom "$sMaxZoom" \
        --increment "$increment" \
        --oMaxZoom "$oMaxZoom" \
        --oDir "$oDir"

    if [[ "$verbose" = "true" ]]; then
        echo "process_tile: [END] Finished processing $zoom_level-$x_coord-$y_coord"
    fi
}
export -f process_tile

# Function to generate tile coordinates and output them as a single space delimited string variable.
generate_tile_coordinates() {
    local zoom_level=$1
    local tiles_in_dimension=$(echo "2^$zoom_level" | bc)

    local output=""

    for ((y = 0; y < $tiles_in_dimension; y++)); do
        for ((x = 0; x < $tiles_in_dimension; x++)); do
            output+="$zoom_level $x $y "
        done
    done

    echo -n "$output"
    return
}

run_option_2() {
    local programOptions="$1"
    read oMinZoom demUrl oDir increment sMaxZoom sEncoding oMaxZoom verbose <<<"$programOptions"

    echo "Source File: $demUrl"
    echo "Source Max Zoom: $sMaxZoom"
    echo "Source Encoding: $sEncoding"
    echo "Output Directory: $oDir"
    echo "Output Min Zoom: $oMinZoom"
    echo "Output Max Zoom: $oMaxZoom"
    echo "Contour Increment: $increment"
    echo "Main: [START] Processing tiles."
    
    # Capture the return value using a pipe.
    tile_coords_str=$(generate_tile_coordinates "$oMinZoom")

    if [[ $? -eq 0 ]]; then
        if [[ "$verbose" = "true" ]]; then
            echo "Main: [INFO] Starting tile processing for zoom level $oMinZoom"
        fi
        #Ensure xargs only runs if it doesn't receive a signal
         trap_return() {
           if [ $? -ne 0 ]; then
              echo "Exiting..." >&2
             exit 1
           fi
        }
       trap  trap_return  INT TERM 
	    echo "$tile_coords_str" | xargs -P 8 -n 3 bash -c 'process_tile "$1" "$2" "$3"' "$programOptions"
        if [[ "$verbose" = "true" ]]; then
            echo "Main: [INFO] Finished tile processing for zoom level $oMinZoom"
        fi
    else
        echo "Error generating tiles" >&2
        exit 1
    fi

    echo "Main: [END] Finished processing all tiles at zoom level $oMinZoom."
}

# --- Main Script ---
if [[ $# -eq 0 ]]; then
    usage
    exit 1
fi

function="$1"
shift

# Trap SIGINT and SIGTERM signals
trap 'kill $(jobs -p); exit 1' INT TERM

case "$function" in
"generate-tile-pyramid")
    programOptions=$(parse_arguments_option_1 "$@")
    ret=$? # capture exit status
    if [[ "$ret" -ne 0 ]]; then
        exit "$ret"
    fi
    run_option_1 "$programOptions"
    ;;
"generate-zoom-level")
    programOptions=$(parse_arguments_option_2 "$@")
    ret=$? # capture exit status
    if [[ "$ret" -ne 0 ]]; then
        exit "$ret"
    fi
    run_option_2 "$programOptions"
    ;;
*)
    echo "Invalid function: $function" >&2
    usage
    exit 1
    ;;
esac