# openfoambaja
a very simple snappyhexmesh and simpleFOAM Baja SAE OpenFOAM case. modified around motorcycle tutorial 

# tech spex 

**physics and initial conditions**
<br>

solver: simplefoam
<br>

turbulence model: k omega SST 
<br>

inlet velocity: 13 m/s in positive X 
<br>

fluid: incompressible air, normalized pressure via density
<br>


**boundary conditions**
| go illini     | v(u)        | p(p)         | turb(k)        |
|---------------|-------------|--------------|----------------|
| inlet         | 13 m/s      | zeroGradient | fixed          |
| outlet        | inletOutlet | 0            | inletOutlet    |
| BajaSurface   | noSlip      | zeroGradient | Wall Functions |
| floor ceiling | slip        | zeroGradient | slip           |
<br>

**parallelization**
<br>

defaults to 8 cores as defined in the CORES variable in the bash script 
<br>

**STL centering**
<br>

spins the car 180 deg, due to how natilee stl exported, likely delete ts if ur car isnt backwards
<br>

creates a translational vector to automatically centre on the y-axis
<br>

## pipeline

blockmesh/surfaceFeatureExtract/snappyHexMesh
decomposeParDict/simpleFoam/reconstructPar

<br>

## ENSURE MODEL IN baja.stl IN constant/triSurface/!!! BACKUP AND REPLACE MODEL AFTER EACH RUN!
