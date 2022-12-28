
class PackageVariant {
    # Name of the variant (can be anything)
    [string]$Name
    # Platform name (must be one supported by Unreal e.g. Win64)
    [string]$Platform
    # Configuration name i.e. Development, Shipping
    [string]$Configuration
    # List of cultures to cook into this variant. If omitted, use the project packaging settings
    [array]$Cultures
    # Additional arguments to send to the build command line
    [string]$ExtraBuildArguments
    # Whether to create a zip of this package (default false)
    [bool]$Zip
    # List of services this variant should be released to ("steam", "itch" currently supported)
    [array]$ReleaseTo
    # The Steam application ID, if you intend to send this variant to Steam
    [string]$SteamAppId
    # The Steam depot ID, if you intend to send this variant to Steam
    [string]$SteamDepotId
     # Steam login to use to deploy to Steam (if you haven't cached your credential already you'll get a login prompt)
     [string]$SteamLogin
     # Itch application identifier e.g. your-account/game-name, if you intend to send this variant to Itch
    [string]$ItchAppId
    # Itch channel, if you intend to send this variant to Itch (usually a platform)
    [string]$ItchChannel

    PackageVariant() {
        $this.Configuration = "Development"
        $this.Zip = $false
    }
    PackageVariant([PSCustomObject]$obj) {
        $this.Configuration = "Development"
        $this.Zip = $false

        # Override just properties that are set
        $obj.PSObject.Properties | ForEach-Object {
            try {
                $this.$($_.Name) = $_.Value
            } catch {
                Write-Host "Invalid property for package variant: $($_.Name) = $($_.Value)"
            }
        }

    }
}

# Our config for both building and releasing
# Note that environment variables also have an effect:
# - UEINSTALL: a specific UE install to use (default blank, find a version in UEROOT)
# - UEROOT: Parent folder of all binary UE installs (default C:\Program Files\Epic Games)
class PackageConfig {
    # The root of the folder structure which will contain packaged output
    # Will be structured $OutputDir/$version/$variant
    # If relative, will be considered relative to source folder
    [string]$OutputDir
    # Folder to place zipped releases (named $target_$platform_$variant_$version.zip)
    # If relative, will be considered relative to source folder
    [string]$ZipDir
    # Optional project file name (relative or absolute). If missing will detect .uproject in source folder
    [string]$ProjectFile
    # Target name: this will usually be the name of your game
    [string]$Target
    # Whether to cook all maps (default true)
    [bool]$CookAllMaps
    # If CookAllMaps=false, list the map names you want to cook
    [array]$MapsIncluded
    # If CookAllMaps=true, list the map names you want to exclude from cooking
    [array]$MapsExcluded
    # Whether to combine assets into a pak file (default true)
    [bool]$UsePak
    # List of PackageVariant entries
    [array]$Variants
    # Names of the default variant(s) to package / release if unspecified
    [array]$DefaultVariants

    PackageConfig([PSCustomObject]$obj) {
        # Construct from JSON object
        $this.CookAllMaps = $false
        $this.UsePak = $true
        $this.Variants = @()

        # Override just properties that are set
        $obj.PSObject.Properties | ForEach-Object {
            if ($_.Name -ne "Variants") {
                try {
                    # Nested array dealt with below
                    $this.$($_.Name) = $_.Value
                } catch {
                    Write-Host "Invalid property in root package config: $($_.Name) = $($_.Value)"
                }
            }
        }

        $this.Variants = $obj.Variants | ForEach-Object {
            [PackageVariant]::New($_)
        }
    }
    
    
}

# Read packageconfig.json file from a source location and return PackageConfig instance
function Read-Package-Config {
    param (
        [string]$srcfolder
    )

    $configfile = Resolve-Path "$srcfolder\packageconfig.json"
    if (-not (Test-Path $configfile -PathType Leaf)) {
        throw "$srcfolder\packageconfig.json does not exist!"
    }

    $obj = (Get-Content $configfile) | ConvertFrom-Json

    return [PackageConfig]::New($obj)

}
