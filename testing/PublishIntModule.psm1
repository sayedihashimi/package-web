# gloabal variables
$paramNameIISApp = "IIS Web Application Name"
$paramNameAuthType = "AuthType"
$paramNameAllowUntrusted = "Allow untrusted certificate"
$publishConfigExpectedFilename = "PublishConfiguration.ps1"
$publishConfigReadmeFilename = ("{0}.readme" -f $publishConfigExpectedFilename)

$userOptions = @{}
# if a specific msdeploy.exe should be used it needs to be specified in this option
$userOptions["msdeployPath"] = $null

# references
# http://consultingblogs.emc.com/matthall/archive/2009/09/22/powershell-zip-files-on-network-drive.aspx
# http://luke.breuer.com/time/item/Powershell_verify_zip_file_contents/467.aspx
function Extract-Zip
{
	param([string]$zipfilename, [string] $destination)

	if(test-path($zipfilename))
	{	
		$shellApplication = new-object -com shell.application
		$zipPackage = $shellApplication.NameSpace($zipfilename)
		$destinationFolder = $shellApplication.NameSpace($destination)
		$destinationFolder.CopyHere($zipPackage.Items())
	}
    else{
        Write-Error ("Zipfile not found [{0}]" -f $zipFilename)
    }
}

function GetZipFileForPublishing {
    param($rootFolder)
    # this will look in $rootFolder for zip files, if there is only 1 it will return that one
    # if there is more then it will prompt the user to pick which one
    $selectedZipFile = $null;
    
    Write-Host ("rootFolder: {0}" -f $rootFolder) | Out-Null
    $zipFiles = Get-ChildItem *.zip -Path $rootFolder
    Write-Host ("zipFiles.Count: {0}" -f $zipFiles.Count) | Out-Null
    if( $zipFiles -is [system.array] ) {
        # print the names of all the files and then ask the user which one to use
        Write-Host "Found these .zip files in this folder"
        $zipFiles | ForEach-Object {Write-Host ("    " + $_.Name) -foregroundcolor cyan}
        Write-Host "Enter the name of the package which you want to publish"
        $result = Read-Host
        $selectedZipFile = Get-ChildItem $result
    }
    else {
        $selectedZipFile = $zipFiles
    }   
    
    return $selectedZipFile
}

function GetTransforms {
    [string]$deployTempFolder
    # look through the folder for files like t.web.*.config and return the list of values for *
    $transformFileNamesRaw = Get-ChildItem $deployFolder | where {$_.Name -match "t.web.+.config"}
    $transformFileNames = @()
    foreach($transformName in $transformFileNamesRaw) {
        # remove the "t.web." from the front
        $tName = $transformName.Name.Remove(0,6)
        # remove the ".config" from the end
        $tName = $tName.Remove($tName.length-7,7)
        
        if( $tName -is [string] -and $tName.length -gt 2 ) {
            $transformFileNames += $tName
        }
    }
    return $transformFileNames
}

function GetSelectedTransform {
    [string]$deployTempFolder
    $transformNames=GetTransforms -deployTempFolder $deployTempFolder
    $selectedTransform = $null
    
    if($transformNames -is [system.array]){
    
        if($NonInteractive) {
            $passedInTransform = FindParamByName -allParams $scriptParams -name "TransformName"
            if($passedInTransform) {
                $selectedTransform = $passedInTransform.value  
            }
            # $selectedTransform = FindParamByName -allParams $scriptParams -name "TransformName"
        }
        else {
            # prompt the user for which one that should be used
            $e = Write-Host "Found these transforms"
            $transformNames | ForEach-Object {
                if($_.length -gt 1) {
                    Write-Host ("    " + $_) -foregroundcolor cyan
                }}
            $e = Write-Host "Enter the name of the transform which you would like to execute during publish (blank to skip transform)"
            $e = Write-Host ("    >") -NoNewline -ForegroundColor gray
            $result=Read-Host
            $selectedTransform = $result.ToString().trim()
        }
    }
    else {
        # since there is only 1 just select this one
        $selectedTransform = $transformNames.Name
    }   
    
    $result = (""+$selectedTransform).Trim()
    
    return $result
}

function GetPathToMSDeploy {
    $msdInstallLoc = $userOptions["msdeployPath"]
    if(!($msdInstallLoc)) {       
        $progFilesFolder = (Get-ChildItem env:"ProgramFiles").Value
        $msdLocToCheck = @()
        $msdLocToCheck += ("{0}\IIS\Microsoft Web Deploy V3\msdeploy.exe" -f $progFilesFolder)
        $msdLocToCheck += ("{0}\IIS\Microsoft Web Deploy V2\msdeploy.exe" -f $progFilesFolder)
        $msdLocToCheck += ("{0}\IIS\Microsoft Web Deploy\msdeploy.exe" -f $progFilesFolder)
           
        foreach($locToCheck in $msdLocToCheck) {
            "Looking for msdeploy.exe at [{0}]" -f $locToCheck | Write-Verbose | Out-Null
            if(Test-Path $locToCheck) {
                $msdInstallLoc = $locToCheck
                break;
            }
        }
        
    }
    
    if($msdInstallLoc){
        "Found msdeploy.exe at [{0}]" -f $msdInstallLoc |Write-Verbose | Out-Null
    }
    else {
        throw "Unable to find msdeploy.exe, please install it and try again"
    }
    
    return $msdInstallLoc
}

function GetParametersFromPackage {
    param([string]$packagePath)
    
    if(!(Test-Path $packagePath)) {
        Write-Error ("Package not found at [{0}]" -f $pkgParametersFile)
    }

    $msdeployExe=GetPathToMSDeploy
    $msdArgs="-verb:getParameters -source:package=""" + $packagePath + """"
    
    # Write-Host ("msdArgs: " + $msdArgs) -Debug
 
    $pkgParametersFile= Join-Path -Path $tempPublishFolder -ChildPath "params.xml"

    # due to escaping issues, write the command into a .cmd file and invoke that
    # it will output the parameters of the package into a XML file at $pkgParametersFile
    $exp = ("""{0}"" {1} > {2}" -f $msdeployExe, $msdArgs,$pkgParametersFile)
    Write-Host ("Expression: " + $exp) -Debug

    $cmdFile = Join-Path -Path $tempPublishFolder -ChildPath "pub.cmd"
    
    # create the .cmd file
    $exp | Out-File -Encoding "ASCII" $cmdFile

    # invoke the .cmd file
    $e = Invoke-Expression $cmdFile

    # now let's read the file and get the list of parameters inside of it
    $paramArray = @()
    [xml]$parameters = Get-Content $pkgParametersFile
    foreach($p in $parameters.output.parameters.parameter){
        $name = $p.name
        $defaultValue = $p.defaultValue
        
        $str = "name:{0}, defaultValue:{1}" -f $name, $defaultValue
        # Write-Host $str
        
        $paramArray += @{name=$name; defaultValue=$defaultValue}
    }
    
    return $paramArray
}

function ConvertTo-PlainText( [security.securestring]$secure ) {
    # taken from: http://www.vistax64.com/powershell/159190-read-host-assecurestring-problem.html
	$marshal = [Runtime.InteropServices.Marshal]
	$e = $marshal::PtrToStringAuto( $marshal::SecureStringToBSTR($secure) )
    return $e
}

function PromptUserForParameterValues {
    param([system.array]$paramValues)

    $e = Write-Host "********************************************************************************" -ForegroundColor yellow
    $e = Write-Host "    Now collecting parameters for publishing" -ForegroundColor yellow
    $e = Write-Host "    You can press <enter> to go with default values" -ForegroundColor yellow
    $e = Write-Host "    For an empty string use a single space" -ForegroundColor yellow
    $e = Write-Host "    Parameter names in " -ForegroundColor yellow -NoNewline
    $e = Write-Host "green" -ForegroundColor green
    $e = Write-Host "    Default parameter values in " -NoNewline -ForegroundColor yellow
    $e = Write-Host "cyan" -ForegroundColor cyan
    $e = Write-Host "********************************************************************************" -ForegroundColor yellow

    $allParams = @()
    $allParams += @{name="Computer name";defaultValue="localhost";isInternalParameter=$true}
    $allParams += @{name="Username";defaultValue="";isInternalParameter=$true}
    $allParams += @{name="Password";defaultValue="";isInternalParameter=$true;isSecure=$true}
    # $allParams += @{name="Site name";defaultValue="";isInternalParameter=$true}
    $allParams += @{name=("{0}" -f $paramNameAllowUntrusted);defaultValue="false";isInternalParameter=$true}
    $allParams += @{name="whatif";defaultValue="false";isInternalParameter=$true}
    $allParams += $paramValues
    
    foreach($p in $allParams) {
        $e = Write-Host ("    " + $p.name) -ForegroundColor green -NoNewline
        $e = Write-Host ": " -NoNewline
        $e = Write-Host $p.defaultValue -ForegroundColor cyan
        # $str = "{0}: value={1}" -f $p.Name, $p.defaultValue   
        # Write-Host $str -ForegroundColor green
        $e = Write-Host ("        new value>") -NoNewline -ForegroundColor gray                       
        
        if($NonInteractive) {
            # we will get all parameters from the $scriptParams
            $foundParamValue = FindParamByName -allParams $scriptParams -name $p.Name
            if($foundParamValue) {
                $value = $foundParamValue.value
            }
            else {
                $value = $p.defaultValue
            }       
        }
        else { 
            if($p.isSecure) {
                $secString = Read-Host -AsSecureString
                $value = ConvertTo-PlainText -secure $secString
            }
            else {
                $value = Read-Host
            }
        }       
        
        if($value){
            $value = $value.trim()
        }
        
        if($value.length -le 0) {
            $value = $p.defaultValue
        }
        $p.value = $value
    }
       
    return $allParams
}

function CreateSetParametersFile {
    param([string]$setParametersFilePath,[system.array]$paramValues)
    
    $xmlDoc = New-Object System.Xml.XmlDocument
    $root = $xmlDoc.createElement("parameters")
    $e = $xmlDoc.appendChild($root)
    foreach($p in $paramValues) {
            if(!($p.isInternalParameter)) {
            $paramElement = $xmlDoc.createElement("setParameter")
            $e = $root.appendChild($paramElement)
            $e = $paramElement.setAttribute("name",$p.name)
            $e = $paramElement.setAttribute("value",$p.value)
        }
    }    
    
    $e = $xmlDoc.save($setParametersFilePath)
}

function IsComputerNameLocalhost {
    param($compName)
    $result = $false
    # compare with  "localhost" or the name of the computer
    
    $compName = $compName.Trim()
    
    $thisComputerName = $env:ComputerName
    if($compName -ceq "localhost" -or $compName -ceq $thisComputerName) {
        $result = $true
    }
    
    return $result
}

function BuildMSDeployCommand {
    param([string]$deployFolder,[string]$setParametersFilePath,[system.array]$paramValues)
#"C:\Program Files\IIS\Microsoft Web Deploy V2\\msdeploy.exe" 
#    -source:archiveDir='C:\Data\...\Foo\' 
#    -dest:auto,includeAcls='False' 
#    -verb:sync 
#    -disableLink:AppPoolExtension -disableLink:ContentExtension -disableLink:CertificateExtension 
#    -setParamFile:"C:\Data\...\SetParameters.xml" 
#    -whatif

    # Computer name parameter
    $compNameParamValue = ($paramValues | Where-Object{$_.name -eq "Computer name"}).Value
    $compNameCommandFrag = ""
    $isCompNameLocalhost = IsComputerNameLocalhost -compName $compNameParamValue
    if($compNameParamValue.length -gt 0 -and !$isCompNameLocalhost) {
        # Since this is not for localhost we need to combine site name with this for hoster scenarios
        $siteNameParam = FindParamByName -allParams $paramValues -name $paramNameIISApp
        $compNameCommandFrag = ",ComputerName={0}?site={1}" -f $compNameParamValue, $siteNameParam.Value
    }

    # Auth type parameter
    $authType = "Basic"
    # see if there is a param with the name 
    $authTypeParam = FindParamByName -allParams $paramValues -name $paramNameIISApp
    if($authTypeParam -and $authTypeParam.Length -gt 0) {
        $authType = $authTypeParam.Value
    }
    else {
        # try and pick a good default
        if($isCompNameLocalhost) {
            $authType = "NTLM"
        }
        else {
            $authType = "BASIC"
        }
    }
    $authTypeCommandFrag = (",AuthType='{0}'" -f $authType)


    $whatIf = [system.convert]::ToBoolean(($paramValues | Where-Object{$_.name -eq "whatif"}).Value)
    $whatIfCommandFrag = ""
    if($whatif) {
        $whatIfCommandFrag = "-whatif"
    }    
    
    $userNameParamValue = ($paramValues | Where-Object{$_.name -eq "Username"}).Value
    $usernameCommandFrag = ""
    if($userNameParamValue.length -gt 0){
        $usernameCommandFrag = ",Username={0}" -f $userNameParamValue
    }
    
    $passwordParamvalue = ($paramValues | Where-Object{$_.name -eq "Password"}).Value
    $passwordCommandFrag = ""
    if($passwordParamvalue.length -gt 0) {
        $passwordCommandFrag = ",Password={0}" -f $passwordParamvalue
    }

    # AllowUntrusted
    $allowUntrusted = $false
    $alllowUntrustedParam = FindParamByName -allParams $paramValues -name $paramNameAllowUntrusted
    if($alllowUntrustedParam -and $alllowUntrustedParam.Length -gt 0) {
        $allowUntrusted = [system.convert]::ToBoolean($alllowUntrustedParam)
    }

    $msdExe = GetPathToMSDeploy
    $msdCommand = """{0}"" -verb:sync -source:archiveDir=""{1}"" -dest:auto,includeAcls='False'{2}{3}{4}{5} -disableLink:AppPoolExtension -disableLink:ContentExtension -disableLink:CertificateExtension" -f $msdExe,$deployFolder,$compNameCommandFrag,$usernameCommandFrag,$passwordCommandFrag,$authTypeCommandFrag
    $msdCommand = "{0} -setParamFile:""{1}"" {2}" -f $msdCommand, $setParametersFilePath, $whatIfCommandFrag
    # add the skip for the _Deploy_ folder
    $msdCommand = "{0} {1}" -f $msdCommand, "-skip:objectName=dirPath,absolutePath=""_Deploy_"""    
    # add the skip for web.*.config
    $msdCommand += " -skip:objectName=filePath,absolutePath=web\..*\.config"
    $msdCommnad += " -retryAttempts=2"
    
    if($allowUntrusted) {
        $msdCommand += " -allowUntrusted"
    }
    
    $e = Write-Host "MSDeploy command:" -ForegroundColor green
    $e = Write-Host $msdCommand -ForegroundColor green
    
    return $msdCommand
}

function PublishWithMSDeploy {
    param([string]$msdCommand)

    $e = Write-Verbose "Starting publish process"
    
    # due to escaping issues, write the file into a .cmd and then execute that file
    $cmdFile = Join-Path -Path $tempPublishFolder -ChildPath "pub.msdeploy.cmd"
    # create the .cmd file
    $e = $msdCommand | Out-File -Encoding "ASCII" $cmdFile
    
    # invoke the .cmd file to perform the publish
    Invoke-Expression $cmdFile
    $e = Write-Verbose "Publish completed"
}

function FindParamByName {
    param($allParams,$name)
    
    foreach($p in $allParams){
        if( $p.Name -ceq $name) {
            return $p
        }
    }
}

function EscapePowershellString {
    param([string]$strToEscape)
    
    $newString = $strToEscape
    $strsToEscape = @()
    $strsToEscape += @{str='"';replacement='""'}
    
    foreach($str in $strsToEscape) {
        $newString = ($newString -replace $str.str,$str.replacement)
    }
    
    return $newString
}

# This will create a .ps1.readme file that contains all the
# parameters which are needed for a re-entrant publish
function WriteFileForNextTime {
    param([string]$destFolder,[string]$tempFolder,$paramsToWriteToFile)
    
    # first write it out to the temp folder and then try and copy it to the final location
    
    $strToWrite = 
@"
############################################################
# This file is generated by a tool, if you want to automate your publish (i.e. so that you don't have to enter parameter
# values each time) you can rename this file to have a .ps1 extension.
#
# If this file is detected with a .ps1 extension in the same folder as the Publish-Interactive.ps1 file then it will be
# used instead of prompting for parameter values.
#
# For secure values (i.e. password) a token 'REPLACE-WITH-VALUE' will be written out instead of the actual value.
#
# NOTE: Each time that the Publish-Interactive.ps1 file is executed it will re-write PublishConfiguration.ps1.readme so if
# you modify the file you should rename it as well.
############################################################
"@
    
    # for secure values don't write the actual value but insert a placeholder instead
    
    # we will write out a PS script which has all the values
    $strToWrite += "`n`n`n`$settingsFromUser =@() `n"
    foreach($setting in $paramsToWriteToFile) {
        $name = EscapePowershellString -strToEscape $setting.Name
        $value = EscapePowershellString -strToEscape $setting.Value
        
        if($setting.isSecure) {
            $value = "REPLACE-WITH-VALUE"
        }
        
        $str = ("`$settingsFromUser += @{{name=""{0}"";value=""{1}""}}`n" -f $name, $value)
        $strToWrite += ($str)
    }
    
    $fileName = $publishConfigReadmeFilename
    
    $strToWrite += "`n"

    $destTempFile = Join-Path -Path $tempFolder -ChildPath $fileName
    
    $destTempFileWritten = $false
    try {
        Set-Content -Path $destTempFile -Value $strToWrite
        $destTempFileWritten = $true
    }
    catch {
        $message = ("Unable to write publish config file at ['{0}']" -f $destTempFile)
        Write-Error $message
    }
    
    if($destTempFileWritten -and !$NonInteractive) {
        try {
            $destFilePath = Join-Path -Path $destFolder -ChildPath $fileName
            Copy-Item -Path $destTempFile -Destination $destFilePath
            
            Write-Host "`n`n********************************************************`n" -ForegroundColor green | Out-Null
            Write-Host ("   Wrote publish config file to .\{0}" -f $fileName) -ForegroundColor yellow | Out-Null
            Write-Host ("   If you want to avoid all the prompts next time remove the .readme extension") -ForegroundColor yellow | Out-Null
            Write-Host "`n********************************************************" -ForegroundColor green | Out-Null
    
        }
        catch {
            $message = ("Unable to copy publish config file to ['{0}']" -f $destTempFile)
            Write-Error $message
        }
    }
    
    
}

# This will print out the command line that the user can use to avoid all the prompts
function PrintCommandLineForNextTime {
    param($currentFile,$allParams)
    
    Write-Host ("allParams.Length: {0}" -f $allParams.Length)
    
    # .\ -NonInteractive "TransformName=Release" "IIS Web Application Name=Default Web Site/FooBar" "ApplicationServices-Web.config Connection String=data source=foo value"
    $cmdLineToPrint = "`n`n********************************************************`n"
    $cmdLineToPrint += "You can use the command below to automate this same publish next time`n     "
    $cmdLineToPrint | Write-Host -ForegroundColor green
    
    $cmdLineToPrint = ".\{0} -NonInteractive" -f $currentFile.Name
    
    foreach($sp in $allParams){
        $name = $sp.Name.Trim()
        
        $value = $sp.Value
        if(!$value){
            $value = $sp.DefaultValue
        }
        
        # only add if the param has a value
        if($value -and ($value.Trim().Length -gt 0)) {
            $value = $value.Trim()

            $cmdLineToPrint += (" ""{0}={1}""" -f $name,$value)
        }
        else {
            # TODO: Add warning?
        }
    }
    
    Write-Host $cmdLineToPrint -ForegroundColor yellow
    
    $cmdLineToPrint = "`n********************************************************`n`n"
    
    Write-Host $cmdLineToPrint -ForegroundColor green
}

$gs = @()

function GetParameterValuesFromFile {
    param([string]$currentDir=$(throw "GetParameterValuesFromFile requires a value for currentDir"),
          $settingsContainer=$(throw "GetParameterValuesFromFile requires a value for settingsContainer"))

    if(!(Test-Path $currentDir)) {
        $msg = ("Path given to GetParameterValuesFromFile doesn't exist, path [{0}]" -f $currentDir)
        throw $msg
    }
    
    $publishConfigFullPath = (Join-Path $currentDir -ChildPath $publishConfigExpectedFilename)
    
    # we need to read the file, invoke it and return the value for $settingsFromUser
    if(Test-Path $publishConfigFullPath) {
        "Getting parameters from file [{0}]" -f $publishConfigFullPath | Write-Verbose | Out-Null        
        
        # we need to insert the fake delimiter because we want a single string not an array
        $strToExecute = (Get-Content $publishConfigFullPath -Delimiter "fakedelimter")
        
        Invoke-Expression $strToExecute | Out-Null
        "Detected parameters file, you will not be prompted for parameters. File= [{0}] " -f $publishConfigFullPath | Write-Host -ForegroundColor yellow | Out-Null
        # Write-Host ("Detected parameters file, you will not be prompted for parameters. File= [{0}] " -f $publishConfigFullPath)
        
        if($settingsFromUser){
            $NonInteractive = $true
            $settingsContainer += $settingsFromUser
        }
        
        $gs = $settingsFromUser
        
        return $settingsFromUser
    }
    else {
        Write-Host ("No params file found at: [{0}]" -f $publishConfigFullPath) | Out-Null
    }
}

# ***************************************
# End functions, begin the script
# ***************************************

