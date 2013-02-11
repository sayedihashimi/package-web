param($rootPath, $toolsPath, $package, $project)

# When the package is installed into a project we need to perform the following steps:
# 1. Create a .wpp.targets file if it doesn't already exist
# 2. If the .wpp.targets doesn't have an import for Sedodream.Package.proj then insert one

$pwMsbuildLabel = "PackageWeb"

function WriteParamsToFile {
    param([string]$filePath)
    
    $strToWrite="rootPath={0}`r`ntoolsPath={1}`r`npackage={2}`r`nproject path={3}`r`n" -f $rootPath, $toolsPath, $package, $project.FullName
    
    Write-Debug ("params: {0}" -f $strToWrite)
    
    $strToWrite | Out-File $filePath
}

function CreateWppTargetsFile {
    param($project)
    
    $projName = $project.Name
    $projFile = Get-Item ($project.FullName)
    $projDirectory = $projFile.DirectoryName
    
    $wppTargetsPath = Join-Path $projDirectory -ChildPath ("{0}.wpp.targets" -f $projName)
    $wppTargetsExists = Test-Path $wppTargetsPath
    
    
    $msbuildProj = $null
    $projCollection = New-Object Microsoft.Build.Evaluation.ProjectCollection
    if(!($wppTargetsExists)) {
        Write-Debug ("    Creating MSBuild file at {0}" -f $wppTargetsPath) | Out-Null
        # create a new file there        
        $msbuildProj = (New-Object Microsoft.Build.Evaluation.Project -ArgumentList $projCollection)
        $msbuildProj.Save($wppTargetsPath)
    }
    else {
        # file already exists let's load it
        Write-Debug ("    MSBuild file already exists at {0}" -f $wppTargetsPath) | Out-Null
        $projCollection.LoadProject($wppTargetsPath) | Out-Null
    }
    
    $projRoot = [Microsoft.Build.Construction.ProjectRootElement]::Open($wppTargetsPath)
    # now we need to see if the file has the import that we are looking to add
    $wppTargetsHasImport = DoesProjectHaveImport -projRoot $projRoot
    
    if(!($wppTargetsHasImport)) {
        # we need to add an import to that file now
        AddImportToWppTargets -projRoot $projRoot
    }
    
    # add the .wpp.targets file to the project so that it gets checked in
    $project.ProjectItems.AddFromFile($wppTargetsPath) | Out-Null
    $project.Save() | Out-Null
}

function AddImportToWppTargets {
    param($projRoot)
   
    $targetsPropertyName = "SedodreamPackageFolder"
    $importPath = "`$(MSBuildProjectDirectory)\_Package\"
    $importCondition = " '`$(SedodreamPackageFolder)'=='' "
    
    $importFileName = "Sedodream.Package.targets"
    
    # add the property for the import location 
    $propGroup = $projRoot.AddPropertyGroup()
    $ppe = $propGroup.AddProperty($targetsPropertyName,$importPath)
    $e = $ppe.Condition = (" '`$({0})'=='' " -f $ppe.Name)
    $propGroup.Label = $pwMsbuildLabel
	
    # add the import itself
    $importStr = ("`$({0}){1}" -f $targetsPropertyName, $importFileName)
    $importElement = $projRoot.AddImport($importStr)
    $importElement.Label = $pwMsbuildLabel
    $importElement.Condition= ("Exists('{0}')" -f $importStr)
    $projRoot.Save() | Out-Null
}

function DoesProjectHaveImport {
    param($projRoot)
        
    $hasImport = $false
    foreach($pie in $projRoot.Imports) {
        # see if it has the expected label
        if($pie -ne $null -and $pie.Label -ne $null -and $pie.Label.Trim() -ceq $pwMsbuildLabel) {
            $hasImport = $true
            break
        }               
    }
    
    return $hasImport
}

# WriteParamsToFile -filePath "C:\temp\sayedha-ps.txt"

CreateWppTargetsFile -project $project





