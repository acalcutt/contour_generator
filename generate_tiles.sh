#!/bin/bash

# Default Values
verbose_default=false
increment_default=0
sMaxZoom_default=8
sEncoding_default="mapbox"
oMaxZoom_default=8
oMinZoom_default=5
oDir_default="./output"
processes_default=8

# Function to output usage information
usage_message() {
	echo "Usage: $0 <function> [options]" >&2
	echo "" >&2
	echo "Functions:" >&2
	echo " pyramid   generates contours for a parent tile and all child tiles up to a specified max zoom level." >&2
	echo " zoom      generates a list of parent tiles at a specifed zoom level, then runs pyramid on each of them in parallel" >&2
	echo " bbox      generates a list of parent tiles that cover a bounding box, then runs pyramid on each of them in parallel" >&2
	echo "" >&2
	echo " General Options" >&2
	echo "  --demUrl <string>    The URL of the DEM source. (pmtiles://<http or local file path> or https://<zxyPattern>)" >&2
	echo "  --sEncoding <string> The encoding of the source DEM tiles (e.g., 'terrarium', 'mapbox'). (default: ${sEncoding_default})" >&2
	echo "  --sMaxZoom <number>  The maximum zoom level of the source DEM. (default: ${sMaxZoom_default})" >&2
	echo "  --increment <number> The contour increment value to extract. Use 0 for default thresholds." >&2
	echo "  --oMaxZoom <number>  The maximum zoom level of the output tile pyramid. (default: ${oMaxZoom_default})" >&2
	echo "  --oDir <string>      The output directory where tiles will be stored. (default: ${oDir_default})" >&2
	echo "  --processes <number> The number of parallel processes to use. (default: ${processes_default})" >&2
	echo "" >&2
	echo " Additional Required Options for 'pyramid':" >&2
	echo "  --x <number>   The X coordinate of the parent tile." >&2
	echo "  --y <number>   The Y coordinate of the parent tile." >&2
	echo "  --z <number>   The Z coordinate of the parent tile." >&2
	echo "" >&2
	echo " Additional Required Options for 'zoom':" >&2
	echo "  --oMinZoom <number>  The minimum zoom level of the output tile pyramid. (default: ${oMinZoom_default})" >&2
	echo "" >&2
	echo " Additional Required Options for 'bbox':" >&2
	echo "  --minx <number>  The minimum X coordinate of the bounding box." >&2
	echo "  --miny <number>  The minimum Y coordinate of the bounding box." >&2
	echo "  --maxx <number>  The maximum X coordinate of the bounding box." >&2
	echo "  --maxy <number>  The maximum Y coordinate of the bounding box." >&2
	echo "  --oMinZoom <number>  The minimum zoom level of the output tile pyramid. (default: ${oMinZoom_default})" >&2
	echo "" >&2
	echo "  -v|--verbose  Enable verbose output" >&2
	echo "  -h|--help Show this usage statement" >&2
	echo "" >&2
}

# Function to parse command line arguments for the 'pyramid' function
parse_arguments_function_pyramid() {
	local verbose="${verbose_default}"
	local x=""
	local y=""
	local z=""
	local demUrl=""
	local sEncoding="${sEncoding_default}"
	local sMaxZoom="${sMaxZoom_default}"
	local increment=""
	local oMaxZoom="${oMaxZoom_default}"
	local oDir="${oDir_default}"
	local processes="${processes_default}"

	while [[ $# -gt 0 ]]; do
		case "$1" in
		--x)
			x="$2"
			shift 2
			;;
		--y)
			y="$2"
			shift 2
			;;
		--z)
			z="$2"
			shift 2
			;;
		--demUrl)
			demUrl="$2"
			shift 2
			;;
		--sEncoding)
			sEncoding="$2"
			shift 2
			;;
		--sMaxZoom)
			sMaxZoom="$2"
			shift 2
			;;
		--increment)
			increment="$2"
			shift 2
			;;
		--oMaxZoom)
			oMaxZoom="$2"
			shift 2
			;;
		--oDir)
			oDir="$2"
			shift 2
			;;
		--processes)
			processes="$2"
			shift 2
			;;
		-h | --help)
			usage_message
			exit 1
			;;
		-v | --verbose)
			verbose=true
			shift
			;;
		*)
			echo "Unknown option: $1" >&2
			usage_message
			exit 1
			;;
		esac
	done

	# Check if all required values are provided
	if [[ -z "${x}" || -z "${y}" || -z "${z}" || -z "${demUrl}" || -z "${increment}" ]]; then
		usage_message
		echo "Error: --x, --y, --z, --demUrl, and --increment are required for function pyramid." >&2
		exit 1
	fi

	# check for valid sEncoding
	if [[ "${sEncoding}" != "mapbox" && "${sEncoding}" != "terrarium" ]]; then
		usage_message
		echo "Error: --sEncoding must be either 'mapbox' or 'terrarium'." >&2
		exit 1 # Return non-zero on error
	fi

	echo "${x} ${y} ${z} ${demUrl} ${sEncoding} ${sMaxZoom} ${increment} ${oMaxZoom} ${oDir} ${verbose} ${processes}"
	return 0
}

# Function to parse command line arguments for the 'zoom' function
parse_arguments_function_zoom() {
	local verbose="${verbose_default}"
	local demUrl=""
	local oDir="${oDir_default}"
	local increment="${increment_default}"
	local sMaxZoom="${sMaxZoom_default}"
	local sEncoding="${sEncoding_default}"
	local oMaxZoom="${oMaxZoom_default}"
	local oMinZoom="${oMinZoom_default}"
	local processes="${processes_default}"

	while [[ $# -gt 0 ]]; do
		case "$1" in
		-h | --help)
			usage_message
			exit 1
			;; # Show usage and exit
		--increment)
			increment="$2"
			shift 2
			;;
		--sMaxZoom)
			sMaxZoom="$2"
			shift 2
			;;
		--sEncoding)
			sEncoding="$2"
			shift 2
			;;
		--demUrl)
			demUrl="$2"
			shift 2
			;;
		--oDir)
			oDir="$2"
			shift 2
			;;
		--oMaxZoom)
			oMaxZoom="$2"
			shift 2
			;;
		--oMinZoom)
			oMinZoom="$2"
			shift 2
			;;
		--processes)
			processes="$2"
			shift 2
			;;
		-v | --verbose)
			verbose=true
			shift
			;;
		*)
			echo "Unknown option: $1" >&2
			usage_message
			exit 1
			;; # Return non-zero on error
		esac
	done

	# Check if demUrl is provided
	if [[ -z "${demUrl}" ]]; then
		usage_message
		echo "Error: --demUrl is required." >&2
		exit 1 # Return non-zero on error
	fi

	# Check if sEncoding is valid
	if [[ "${sEncoding}" != "mapbox" && "${sEncoding}" != "terrarium" ]]; then
		usage_message
		echo "Error: --sEncoding must be either 'mapbox' or 'terrarium'." >&2
		exit 1 # Return non-zero on error
	fi

	# Return the values as a single string
	echo "${oMinZoom} ${demUrl} ${oDir} ${increment} ${sMaxZoom} ${sEncoding} ${oMaxZoom} ${verbose} ${processes}"
	return 0 # return zero for success
}

# Function to parse command line arguments for the 'bbox' function
parse_arguments_function_bbox() {
	local minx=""
	local miny=""
	local maxx=""
	local maxy=""
	local demUrl=""
	local sEncoding="${sEncoding_default}"
	local sMaxZoom="${sMaxZoom_default}"
	local increment="${increment_default}"
	local oMinZoom="${oMinZoom_default}"
	local oMaxZoom="${oMaxZoom_default}"
	local oDir="${oDir_default}"
	local verbose="${verbose_default}"
	local processes="${processes_default}"

	while [[ $# -gt 0 ]]; do
		case "$1" in
		--minx)
			minx="$2"
			shift 2
			;;
		--miny)
			miny="$2"
			shift 2
			;;
		--maxx)
			maxx="$2"
			shift 2
			;;
		--maxy)
			maxy="$2"
			shift 2
			;;
		--demUrl)
			demUrl="$2"
			shift 2
			;;
		--sMaxZoom)
			sMaxZoom="$2"
			shift 2
			;;
		--sEncoding)
			sEncoding="$2"
			shift 2
			;;
		--increment)
			increment="$2"
			shift 2
			;;
		--oMaxZoom)
			oMaxZoom="$2"
			shift 2
			;;
		--oMinZoom)
			oMinZoom="$2"
			shift 2
			;;
		--oDir)
			oDir="$2"
			shift 2
			;;
		--processes)
			processes="$2"
			shift 2
			;;
		-h | --help)
			usage_message
			exit 1
			;; # Show usage and exit
		-v | --verbose)
			verbose=true
			shift
			;;
		*)
			echo "Unknown option: $1" >&2
			usage_message
			exit 1
			;; # Return non-zero on error
		esac
	done

	if [[ -z "${minx}" || -z "${miny}" || -z "${maxx}" || -z "${maxy}" || -z "${demUrl}" ]]; then
		echo "Error: --minx, --miny, --maxx, --maxy, and --demUrl are required for function bbox." >&2
		usage_message
		exit 1
	fi

	# Check if sEncoding is valid
	if [[ "${sEncoding}" != "mapbox" && "${sEncoding}" != "terrarium" ]]; then
		usage_message
		echo "Error: --sEncoding must be either 'mapbox' or 'terrarium'." >&2
		exit 1 # Return non-zero on error
	fi

	# Return the values as a single string
	echo "${oMinZoom} ${demUrl} ${oDir} ${increment} ${sMaxZoom} ${sEncoding} ${oMaxZoom} ${verbose} ${processes} ${minx} ${miny} ${maxx} ${maxy}"
	return 0 # return zero for success
}

# Function to generate all tiles at and above a zoom level
process_tile() {
	local programOptions="$0"
	local zoom_level="$1"
	local x_coord="$2"
	local y_coord="$3"

	read -r oMinZoom demUrl oDir increment sMaxZoom sEncoding oMaxZoom verbose processes <<<"${programOptions}"

	if [[ "${verbose}" = "true" ]]; then
		echo "process_tile: [START] Processing tile - Zoom: ${zoom_level}, X: ${x_coord}, Y: ${y_coord}, oMaxZoom: ${oMaxZoom}"
	fi

	npx tsx ./src/generate-countour-tile-pyramid.ts \
		--x "${x_coord}" \
		--y "${y_coord}" \
		--z "${zoom_level}" \
		--demUrl "${demUrl}" \
		--sEncoding "${sEncoding}" \
		--sMaxZoom "${sMaxZoom}" \
		--increment "${increment}" \
		--oMaxZoom "${oMaxZoom}" \
		--oDir "${oDir}"

	if [[ "${verbose}" = "true" ]]; then
		echo "process_tile: [END] Finished processing ${zoom_level}-${x_coord}-${y_coord}"
	fi
}
export -f process_tile

# Function to generate tile coordinates and output them as a single space delimited string variable.
generate_tile_coordinates() {
	local zoom_level="$1"
	local tiles_in_dimension
	tiles_in_dimension=$(echo "2^${zoom_level}" | bc)

	local output=""

	for ((y = 0; y < tiles_in_dimension; y++)); do
		for ((x = 0; x < tiles_in_dimension; x++)); do
			output+="${zoom_level} ${x} ${y} "
		done
	done

	echo -n "${output}"
	return
}

# Function to convert a bounding box to tile coordinates
bbox_to_tiles() {
	local minx="$1"
	local miny="$2"
	local maxx="$3"
	local maxy="$4"
	local zoom="$5"

	local tiles
	tiles=$(npx tsx ./src/bbox_to_tiles.js "${minx}" "${miny}" "${maxx}" "${maxy}" "${zoom}")
	echo "${tiles}"
}
export -f bbox_to_tiles

# Function to run the 'pyramid' command.
run_function_pyramid() {
	local programOptions="$1"
	read -r x y z demUrl sEncoding sMaxZoom increment oMaxZoom oDir verbose processes <<<"${programOptions}"

	if [[ "${verbose}" = "true" ]]; then
		echo "process_tile: [START] Processing tile - Zoom: ${z}, X: ${x}, Y: ${y}, oMaxZoom: ${oMaxZoom}"
	fi

	npx tsx ./src/generate-countour-tile-pyramid.ts --x "${x}" --y "${y}" --z "${z}" --demUrl "${demUrl}" --sEncoding "${sEncoding}" --sMaxZoom "${sMaxZoom}" --increment "${increment}" --oMaxZoom "${oMaxZoom}" --oDir "${oDir}"

	if [[ "${verbose}" = "true" ]]; then
		echo "process_tile: [END] Finished processing ${z}-${x}-${y}"
	fi

	create_metadata "${oDir}" "${z}" "${oMaxZoom}"
}

# Function to run the 'zoom' command.
run_function_zoom() {
	local programOptions="$1"
	read -r oMinZoom demUrl oDir increment sMaxZoom sEncoding oMaxZoom verbose processes <<<"${programOptions}"

	echo "Source File: ${demUrl}"
	echo "Source Max Zoom: ${sMaxZoom}"
	echo "Source Encoding: ${sEncoding}"
	echo "Output Directory: ${oDir}"
	echo "Output Min Zoom: ${oMinZoom}"
	echo "Output Max Zoom: ${oMaxZoom}"
	echo "Contour Increment: ${increment}"
	echo "Main: [START] Processing tiles."

	# Capture the return value using a pipe.
	tile_coords_str=$(generate_tile_coordinates "${oMinZoom}")

	if [[ $? -eq 0 ]]; then
		if [[ "${verbose}" = "true" ]]; then
			echo "Main: [INFO] Starting tile processing for zoom level ${oMinZoom}"
		fi
		#Ensure xargs only runs if it doesn't receive a signal
		trap_return() {
			if [[ $? -ne 0 ]]; then
				echo "Exiting..." >&2
				exit 1
			fi
		}
		trap trap_return INT TERM
		echo "${tile_coords_str}" | xargs -P "${processes}" -n 3 bash -c 'process_tile "$1" "$2" "$3"' "${programOptions}"
		if [[ "${verbose}" = "true" ]]; then
			echo "Main: [INFO] Finished tile processing for zoom level ${oMinZoom}"
		fi
	else
		echo "Error generating tiles" >&2
		exit 1
	fi

	echo "Main: [END] Finished processing all tiles at zoom level ${oMinZoom}."
	create_metadata "${oDir}" "${oMinZoom}" "${oMaxZoom}"
}

# Function to run the 'bbox' command.
run_function_bbox() {
	local programOptions="$1"
	read oMinZoom demUrl oDir increment sMaxZoom sEncoding oMaxZoom verbose processes minx miny maxx maxy <<<"${programOptions}"

	echo "Source File: ${demUrl}"
	echo "Source Max Zoom: ${sMaxZoom}"
	echo "Source Encoding: ${sEncoding}"
	echo "Output Directory: ${oDir}"
	echo "Output Min Zoom: ${oMinZoom}"
	echo "Output Max Zoom: ${oMaxZoom}"
	echo "Contour Increment: ${increment}"
	echo "Main: [START] Processing tiles."

	tile_coords_str=$(bbox_to_tiles "${minx}" "${miny}" "${maxx}" "${maxy}" "${oMinZoom}")

	if [[ $? -eq 0 ]]; then
		if [[ "${verbose}" = "true" ]]; then
			echo "Main: [INFO] Starting tile processing for bounding box"
		fi
		#Ensure xargs only runs if it doesn't receive a signal
		trap_return() {
			if [[ $? -ne 0 ]]; then
				echo "Exiting..." >&2
				exit 1
			fi
		}
		trap trap_return INT TERM
		echo "${tile_coords_str}" | xargs -P "${processes}" -n 3 bash -c 'process_tile "$1" "$2" "$3"' "${programOptions}"
		if [[ "${verbose}" = "true" ]]; then
			echo "Main: [INFO] Finished tile processing for bounding box"
		fi
	else
		echo "Error generating tiles" >&2
		exit 1
	fi

	echo "Main: [END] Finished processing all tiles in bounding box."
	create_metadata "${oDir}" "${oMinZoom}" "${oMaxZoom}"
}

# Function to create the metadata.json file
create_metadata() {
	local outputDir="$1"
	local oMinZoom="$2"
	local oMaxZoom="$3"

	local metadata_file="${outputDir}/metadata.json"
	local metadata_name="Contour_z${oMinZoom}_Z${oMaxZoom}"
	local description
	description=$(date +"%Y-%m-%d %H:%M:%S")

	local json_content='{
    "name": "'"${metadata_name}"'",
    "type": "baselayer",
    "description": "'"${description}"'",
    "version": "1",
    "format": "pbf",
    "minzoom": "'"${oMinZoom}"'",
    "maxzoom": "'"${oMaxZoom}"'",
    "json": "{\"vector_layers\":[{\"id\":\"contours\",\"fields\":{\"ele\":\"Number\",\"level\":\"Number\"},\"minzoom\":'"${oMinZoom}"',\"maxzoom\":'"${oMaxZoom}"'}]}",
    "bounds": "-180.000000,-85.051129,180.000000,85.051129"
}'

	echo "${json_content}" >"${metadata_file}"
	echo "metadata.json has been created in ${outputDir}"
}
export -f create_metadata

# --- Main Script ---
if [[ $# -eq 0 ]]; then
	usage_message
	exit 1
fi

function="$1"
shift

# Trap SIGINT and SIGTERM signals
trap 'kill $(jobs -p); exit 1' INT TERM

case "${function}" in
"pyramid")
	programOptions=$(parse_arguments_function_pyramid "$@")
	ret="$?" # capture exit status
	if [[ "${ret}" -ne 0 ]]; then
		# Error message will already be handled above
		exit "${ret}"
	fi
	run_function_pyramid "${programOptions}"
	;;
"zoom")
	programOptions=$(parse_arguments_function_zoom "$@")
	ret="$?" # capture exit status
	if [[ "${ret}" -ne 0 ]]; then
		# Error message will already be handled above
		exit "${ret}"
	fi
	run_function_zoom "${programOptions}"
	;;
"bbox")
	programOptions=$(parse_arguments_function_bbox "$@")
	ret="$?" # capture exit status
	if [[ "${ret}" -ne 0 ]]; then
		# Error message will already be handled above
		exit "${ret}"
	fi
	run_function_bbox "${programOptions}"
	;;
*)
	echo "Invalid function: ${function}" >&2
	usage_message
	exit 1
	;;
esac
