<#
.SYNOPSIS
Gets the version to use for building a NuGet package
.DESCRIPTION
Get-PackageVersion calculates the version to use,
when a frontend NuGet package is built.

.PARAMETER Branch
The name of the build-* branch from which the NuGet package is built.

.PARAMETER MetaDataJsonPath
The path to the JSON file containing the metadata of a frontend build.

.PARAMETER  MajorMinorPatch
The MajorMinorPatch part of the version.

.EXAMPLE
Get-PackageVersion build-develop .\metdata.json 1.2.3

#>
function Get-PackageVersion
{
  [CmdletBinding()]
  Param(
      [Parameter(Mandatory=$true)]
      [string] $Branch,
      [Parameter(Mandatory=$true)]
      [string] $MetaDataJsonPath,
      [Parameter(Mandatory=$true)]
      [string] $MajorMinorPatch
  )
  Process
  {
    $metadata = Get-Content -Raw $MetaDataJsonPath | ConvertFrom-Json
    $version = $MajorMinorPatch
    $buildBranch = $metadata.'build-branch'
    $paddedBuildNumber = "{0:D4}" -f [int]$metadata.'build-version'
    $Branch = $Branch -replace "refs/heads/", ""
    if($Branch -eq "build-develop") {
        $version + "-develop" + $paddedBuildNumber
    }
    elseif($Branch -eq "build-release" -or $Branch -eq "build-master")  {
        $version + "-release" + $paddedBuildNumber
    }
    else {
        $localBuildBranch = $buildBranch -replace "origin/", ""
        $featureBranch = $localBuildBranch -replace "feature/", ""
        $version + "-" + $featureBranch+ "-" + $paddedBuildNumber
    }
  }
}
