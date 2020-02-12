<#
.SYNOPSIS
Installs all configured NuGet packages to the webroot or to the specified path.


.DESCRIPTION
Installs all NuGet packages which are configured in the Bob.config
either to the web-root or to the specified directory.

.PARAMETER NugetPackage
If the `NugetPackage` parameter is specified only the this packages wil be installed.
If nothing is specified all packages will be installed.

.PARAMETER OutputDirectory
The directory where the packages will be extracted. 
If nothing is specified, the packages will be installed to the web-root. 

.PARAMETER ProjectPath
The path to the website project. If it's not specified, the current Visual Studio website project will be used.

.EXAMPLE
Install-ScNugetPackage

.EXAMPLE
Install-ScNugetPackage Customer.Frontend

.EXAMPLE
Install-ScNugetPackage -OutputDirectory D:\work\project\packing

#>

function Install-ScNugetPackage {
    param(
        [string[]] $NugetPackage,
        [string] $OutputDirectory,
        [string] $ProjectPath
    )

    process {
         function GetPackageVersion {
            param($packageId, $source, $config, $projectPath)

            $gitversion = ResolvePath -PackageId "GitVersion.CommandLine" -RelativePath "tools\Gitversion.exe"
            $versionInfo = & $gitversion "$projectPath" | ConvertFrom-Json
            $version = $versionInfo.MajorMinorPatch

            $releasePattern = "release*"

            $pattern =  & {
                $branch = $versionInfo.BranchName
                switch -wildcard ($branch) {
                    "release/*" {
                        "$version-$releasePattern"
                    }
                    "hotfix/*" {
                        "$version-$releasePattern"
                    }
                    "feature/*" {
                        $featureName = $branch -replace "feature/", ""
                        if ($featureName.length -gt 15) {
                            $featureName = $featureName.Substring(0, 15)
                        }
                        if ($config.FeatureBranchIssueKeyRegex -and $featureName -match $config.FeatureBranchIssueKeyRegex) {
                            "$version-$($featureName)*",  "$version-$($Matches[0])*", "$version-develop*" 
                        }
                        else {
                            "$version-$($featureName)", "$version-develop*"
                        }
                    }
                    default {
                        "$version-develop*"
                    }
                }
            }
            
            if ($pattern -is [array]) {
                $pattern += "*-$releasePattern"
            }
            else {
                $pattern = $pattern, "*-$releasePattern"
            }
            return $pattern
        }

        function GetNugetPackage {
            param($packageId, $versionPatterns, $source)

            $packages = Get-NugetPackage -PackageId $packageId -ProjectPath $ProjectPath -Source $source

            foreach($pattern in $versionPatterns) {
                $possiblePackage =  $packages | where {$_.Version -like $pattern} |  select -Last 1
                if($possiblePackage) {
                    return $possiblePackage
                }            
            }
        }


        
        Invoke-BobCommand {

        $config = Get-ScProjectConfig $ProjectPath

        if(-not $OutputDirectory) {
            $OutputDirectory = $config.WebRoot
        }

        if($NugetPackage) {
            $NugetPackage = $NugetPackage | % {$_.ToLower()}
        } 

        $packages = $config.NugetPackages
        foreach($package in $packages) {

            Write-Verbose "============"
            if($NugetPackage -and -not $NugetPackage.Contains($package.ID.ToLower())) {
                # If the NugetPackage was specified, we only want to install the specified packages.
                Write-Verbose "Skip $($package.ID)"  
                continue;
            }
            Write-Verbose "Start installation of $($package.ID)"

            $versionPatterns = $package.Version
            if(-not $versionPatterns) {
                Write-Verbose "    No version is specified for $($package.ID). Calculate version pattern according to current context:"
                $versionPatterns = GetPackageVersion $package.ID $config.NuGetFeed $config $ProjectPath
            }

            Write-Verbose "    Get newest package of $($package.ID) with version pattern $([string]::Join(", ", $versionPatterns))"

            $nugetPackageToInstall = GetNugetPackage $package.ID $versionPatterns $config.NuGetFeed
            if(-not $nugetPackageToInstall) {
                Write-Error "No package was found with ID $($package.ID) and version pattern  $([string]::Join(", ", $versionPatterns)) on the NuGet feed $($config.NuGetFeed)"
            }
            Write-Verbose "    Found version $($nugetPackageToInstall.Version) of package $($package.ID)"

            if($package.Target) {
                $location = Join-Path $OutputDirectory $package.Target
            }
            else {
                $location = $OutputDirectory
            }

            Write-Verbose "    Start installation of package $($package.ID) $($nugetPackageToInstall.Version) to $location"
            Install-NugetPackage -Package $nugetPackageToInstall -OutputLocation $Location
            Write-Verbose "    Installed version $($package.ID) $($nugetPackageToInstall.Version) to $location"
        }
        }
    }
       
}