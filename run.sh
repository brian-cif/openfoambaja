


#!/bin/bash
# Enable strict error handling
set -eE 
trap 'echo -e "\n SCRIPT FAILED: Error on line $LINENO." >&2; echo "Command: \`$BASH_COMMAND\`" >&2' ERR

# --- 0. LOAD OPENFOAM ENVIRONMENT ---
echo "Loading OpenFOAM environment..."

# 1. Temporarily disable strict error checking (set +e) so harmless 
# errors in OpenFOAM's startup scripts don't kill our pipeline.
set +e 

# 2. Source the environment
source /opt/openfoam13/etc/bashrc

# 3. Re-enable strict error checking (set -eE) for the rest of our script!
set -eE
# --- 1. USER SETTINGS ---
INPUT_STL="baja.stl"
STL_PATH="constant/triSurface/$INPUT_STL"
CORES=8

echo "--- Starting Baja SAE Pipeline (OpenFOAM 13) ---"

# --- 2. INTELLIGENT CLEANUP ---
echo "Cleaning up old simulation data..."
foamListTimes -rm || true
rm -rf processor*
rm -rf constant/polyMesh
rm -rf constant/extendedFeatureEdgeMesh

# --- 3. DYNAMIC STL POSITIONING ---
echo "Calculating dynamic bounding box offsets..."

# 0. SPIN THE CAR AROUND! (Face the inlet at -X)
# We do this first so the bounding box calculations below are perfectly accurate.
surfaceTransformPoints "Rz=180" "$STL_PATH" "$STL_PATH"

# 1. Run surfaceCheck, grab the Bounding Box line, and strip out the parentheses
BBOX_LINE=$(surfaceCheck "$STL_PATH" | grep "^Bounding Box" | tr -d '()')

# 2. Parse the min/max coordinates
XMIN=$(echo "$BBOX_LINE" | awk '{print $4}')
YMIN=$(echo "$BBOX_LINE" | awk '{print $5}')
ZMIN=$(echo "$BBOX_LINE" | awk '{print $6}')
XMAX=$(echo "$BBOX_LINE" | awk '{print $7}')
YMAX=$(echo "$BBOX_LINE" | awk '{print $8}')

# 3. Calculate shifts using awk (to handle floating-point math)
SHIFT_X=$(awk "BEGIN {printf \"%.6f\", -(($XMAX + $XMIN) / 2)}")
SHIFT_Y=$(awk "BEGIN {printf \"%.6f\", -(($YMAX + $YMIN) / 2)}")
SHIFT_Z=$(awk "BEGIN {printf \"%.6f\", -1.001 - $ZMIN}")

echo "Calculated Translation Vector: ($SHIFT_X $SHIFT_Y $SHIFT_Z)"

# 4. Apply the exact translation to drop it on the floor and center it
surfaceTransformPoints "translate=($SHIFT_X $SHIFT_Y $SHIFT_Z)" "$STL_PATH" "$STL_PATH"
# 4. Apply the exact transformation
surfaceTransformPoints "translate=($SHIFT_X $SHIFT_Y $SHIFT_Z)" "$STL_PATH" "$STL_PATH"

# --- 4. MESHING ---
echo "Running blockMesh..."
blockMesh

echo "Extracting features..."
surfaceFeatureExtract

echo "Running snappyHexMesh..."
# -overwrite is now default in OF13, adding the flag causes a crash
snappyHexMesh

# --- 5. SAFE FIELD PREPARATION ---
echo "Syncing 0/ folder..."

if [ ! -d 0.orig ] && [ -d 0 ]; then
    echo "Creating 0.orig backup from current 0 folder..."
    cp -r 0 0.orig
fi

if [ ! -d 0.orig ]; then
    echo "-------------------------------------------------------"
    echo "ERROR: No 0 or 0.orig folder found!"
    echo "-------------------------------------------------------"
    exit 1
fi

rm -rf 0
cp -r 0.orig 0
echo "0/ folder successfully reset from 0.orig."

# --- 6. PARALLEL SETUP ---
if [ ! -f system/decomposeParDict ]; then
    echo "Creating decomposeParDict..."
    cat <<EOF > system/decomposeParDict
FoamFile { version 2.0; format ascii; class dictionary; object decomposeParDict; }
numberOfSubdomains $CORES;
method scotch;
coeffs { }
EOF
fi

echo "Decomposing case for $CORES cores..."
decomposePar -force

# --- 7. SOLVER ---
echo "Running simpleFoam in parallel..."
mpirun -np $CORES simpleFoam -parallel | tee log.simpleFoam

# --- 8. RECONSTRUCT ---
echo "Reconstructing latest results..."
reconstructPar -latestTime

echo "--- Pipeline Complete! ---"
