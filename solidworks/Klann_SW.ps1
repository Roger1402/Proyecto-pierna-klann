# Arma la pierna Klann en SolidWorks 2021 (piezas STEP ya en su pose) y pone las relaciones de posicion.
$ErrorActionPreference='Stop'
$sw='C:\Program Files\SOLIDWORKS Corp\SOLIDWORKS\api\redist'
$refs="$sw\SolidWorks.Interop.sldworks.dll","$sw\SolidWorks.Interop.swconst.dll"
$refs|%{[void][Reflection.Assembly]::LoadFrom($_)}
$src=Get-Content "$PSScriptRoot\KlannSW.cs" -Raw
Add-Type -TypeDefinition $src -ReferencedAssemblies $refs
[KlannSW]::Run($PSScriptRoot,$args[0])
