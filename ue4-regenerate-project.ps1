[CmdletBinding()] # Fail on unknown args
param (
    [string]$src,
    [switch]$dryrun = $false,
    [switch]$help = $false
)

function Write-Usage {
    Write-Output "PirateCat's UE4 Regenerate Project files tool"
    Write-Output "Usage:"
    Write-Output "  ue4-regenerate-project.ps1 [-src:sourcefolder] [-dryrun]"
    Write-Output " "
    Write-Output "  -src                : Source folder (current folder if omitted), must contain packageconfig.json"
    Write-Output "  -dryrun             : Don't perform any actual actions, just report what would happen"
    Write-Output "  -help               : Print this help"
    Write-Output " "
    Write-Output "Environment Variables:"
    Write-Output "  UE4INSTALL   : Use a specific UE4 install."
    Write-Output "               : Default is to find one based on project version, under UE4ROOT"
    Write-Output "  UE4ROOT      : Parent folder of all binary UE4 installs (detects version). "
    Write-Output "               : Default C:\Program Files\Epic Games"
    Write-Output " "
}

$ErrorActionPreference = "Stop"

if ($help) {
    Write-Usage
    Exit 0
}

Write-Output "~-~-~ UE4 Project File Regeneration Helper Start ~-~-~"


if ($src.Length -eq 0) {
    $src = "."
    Write-Verbose "-src not specified, assuming current directory"
}

try {
    if ($src -ne ".") { Push-Location $src }

    # Locate UE4 project file
    $uprojfile = Get-ChildItem *.uproject | Select-Object -expand Name
    if (-not $uprojfile) {
        throw "No Unreal project file found in $(Get-Location)! Aborting."
    }

    if ($uprojfile -is [array]) {
        throw "Multiple Unreal project files found in $(Get-Location)! Aborting."
    }

    $uprojname = [System.IO.Path]::GetFileNameWithoutExtension($uprojfile)
    if ($dryrun) {
        Write-Output "Would regenerate project files for $uprojname"
    } else {
        Write-Output "Regenerating project files for $uprojname"
    }

    # Check version number of UE4 project so we know which version to run
    # We can read this from .uproject which is JSON
    $uproject = Get-Content $uprojfile | ConvertFrom-Json
    $uversion = $uproject.EngineAssociation

    Write-Output "Engine version is $uversion"

    # UE4INSTALL env var should point at the root of the *specific version* of 
    # UE4 you want to use. This is mainly for use in source builds, default is
    # to build it from version number and root of all UE4 binary installs
    $uinstall = $Env:UE4INSTALL

    if (-not $uinstall) {
        # UE4ROOT should be the parent folder of all UE versions
        $uroot = $Env:UE4ROOT
        if (-not $uroot) {
            $uroot = "C:\Program Files\Epic Games"
        } 

        $uinstall = Join-Path $uroot "UE_$uversion"
    }

    $batchfolder = Join-Path "$uinstall" "Engine\Binaries\DotNET"
    $buildTool = Join-Path "$batchfolder" "UnrealBuildTool.exe"
    if (-not (Test-Path $buildTool -PathType Leaf)) {
        throw "UnrealBuildTool.exe missing at $buildTool : Aborting"
    }

    $uprojfileabs = Join-Path "$(Get-Location)" $uprojfile
    $buildargs = "-projectfiles -project=`"${uprojfileabs}`" -game -engine"

    if ($dryrun) {
        Write-Output "Would run: $buildTool $buildargs"
    } else {
        Write-Verbose "Running $buildTool $buildargs"

        $proc = Start-Process $buildTool $buildargs -Wait -PassThru -NoNewWindow
        if ($proc.ExitCode -ne 0) {
            $code = $proc.ExitCode
            throw "*** Process exited with code $code, see above"
        }
    }
    
} catch {
    Write-Output "ERROR: $($_.Exception.Message)"
    $result = 9
} finally {
    if ($src -ne ".") { Pop-Location }
}

Exit $result



#Running C:/Unreal Projects/UnrealEngine 4.25.3/Engine/Binaries/DotNET/UnrealBuildTool.exe  -projectfiles -project="C:/Unreal Projects/ShadowVale/ShadowVale.uproject" -game -engine -progress -log="C:\Unreal Projects\ShadowVale/Saved/Logs/UnrealVersionSelector-2021.09.03-13.06.55.log"

