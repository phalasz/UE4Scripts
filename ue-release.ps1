[CmdletBinding()] # Fail on unknown args
param (
    # Explicit version to release
    [string]$version,
    # Latest version option instead of explicit version
    [switch]$latest,
    # Variant name(s) to release; if not specified release all DefaultVariants with ReleaseTo options
    [array]$variants,
    # Source folder, current dir if omitted
    [string]$src,
    # Which service(s) to release on e.g. "steam": defaults to "ReleaseTo" services in packageconfig.json for variant 
    [array]$services,
    # Dry-run; does nothing but report what *would* have happened
    [switch]$dryrun = $false,
    [switch]$help = $false
)

. $PSScriptRoot\inc\platform.ps1
. $PSScriptRoot\inc\packageconfig.ps1
. $PSScriptRoot\inc\projectversion.ps1
. $PSScriptRoot\inc\uproject.ps1
. $PSScriptRoot\inc\filetools.ps1
. $PSScriptRoot\inc\steam.ps1
. $PSScriptRoot\inc\itch.ps1


function Write-Usage {
    Write-Output "Steve's Unreal release tool"
    Write-Output "Usage:"
    Write-Output "  ue-release.ps1 [-version:ver|-latest] -variant:var -services:steam,itch [-src:sourcefolder] [-dryrun]"
    Write-Output " "
    Write-Output "  -version:ver        : Version to release; must have been packaged already"
    Write-Output "  -latest             : Instead of an explicit version, release one identified in project settings"
    Write-Output "  -variants:var1,var2 : Name of variants to release. Omit to use DefaultVariants"
    Write-Output "  -services:s1,s2     : Name of services to release to. Can omit and rely on ReleaseTo"
    Write-Output "                        setting of variant in packageconfig.json "
    Write-Output "  -src                : Source folder (current folder if omitted), must contain packageconfig.json"
    Write-Output "  -dryrun             : Don't perform any actual actions, just report what would happen"
    Write-Output "  -help               : Print this help"
}

$ErrorActionPreference = "Stop"

if ($help) {
    Write-Usage
    Exit 0
}

if ($src.Length -eq 0) {
    $src = "."
    Write-Verbose "-src not specified, assuming current directory"
}

if (-not $version -and -not $latest) {
    Write-Usage
    Write-Output ""
    Write-Output "ERROR: You must specify a version"
    Exit 1
}

if ($version -and $latest) {
    Write-Usage
    Write-Output ""
    Write-Output "ERROR: You cannot specify a -version and -latest at the same time"
    Exit 1
}

Write-Output "~-~-~ Unreal Release Helper Start ~-~-~"

try {

    # Import config
    $config = Read-Package-Config -srcfolder:$src
    $projfile = Get-Uproject-Filename -srcfolder:$src -config:$config
    $proj = Read-Uproject $projfile
    $ueVersion = Get-UE-Version $proj

    if ($latest) {
        $version = Get-Project-Version $src
    }

    if ($variants) {
        $variantConfigs = $config.Variants | Where-Object { $_.Name -in $variants }
        if ($variantConfigs.Count -ne $variants.Count) {
            $unmatchedVariants = $variants | Where-Object { $_ -notin $variantConfigs.Name } 
            Write-Warning "Variant(s) not found, ignoring: $($unmatchedVariants -join ", ")"
        }
    } else {
        # Use default variants
        $variantConfigs = $config.Variants | Where-Object { $_.Name -in $config.DefaultVariants }
    }

    $hasErrors = $false
    foreach ($variantConfig in $variantConfigs) {

        # Get source dir
        $sourcedir = Get-Package-Client-Dir -config:$config -versionNumber:$version -variantName:$variantConfig.Name -ueVersion:$ueVersion

        if (-not (Test-Path $sourcedir -PathType Container)) {
            Write-Error "Release folder $sourcedir does not exist, skipping"
            $hasErrors = $true
            continue
        }

        # Find service(s)
        if ($services) {
            # Release to a subset of allowed services
            $servicesFound = $services | Where-Object {$variantConfig.ReleaseTo -contains $_ }
            if ($servicesFound.Count -ne $services.Count) {
                $unmatchedServices = $services | Where-Object { $servicesFound -notcontains $_ } 
                Write-Warning "Services(s) not supported by $($variantConfig.Name): $($unmatchedServices -join ", ")"
            }
        } else {
            $servicesFound = $variantConfig.ReleaseTo
        }

        if (-not $servicesFound) {
            Write-Verbose "Skipping $($variantConfig.Name), no matching release services"
            continue
        }

        Write-Output ""
        Write-Output "Variant         : $($variantConfig.Name)"
        Write-Output "Version         : $version"
        Write-Output "Source Folder   : $sourcedir"
        Write-Output "Service(s)      : $($servicesFound -join ", ")"
        Write-Output ""


        foreach ($service in $servicesFound) {
            if ($service -eq "steam") {
                Release-Steam -config:$config -variant:$variantConfig -sourcefolder:$sourcedir -version:$version -dryrun:$dryrun
            } elseif ($service -eq "itch") {
                Release-Itch -config:$config -variant:$variantConfig -sourcefolder:$sourcedir -version:$version -dryrun:$dryrun
            } else {
                throw "Unknown release service: $service"
            }
        }

    }

    if ($hasErrors) {
        throw "Errors occurred, see above"
    }

} catch {
    Write-Output $_.Exception.Message
    Write-Output "~-~-~ Unreal Release Helper FAILED ~-~-~"
    Exit 9
}


Write-Output "~-~-~ Unreal Release Helper Completed OK ~-~-~"
