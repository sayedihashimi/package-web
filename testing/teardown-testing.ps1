set-psdebug -strict -trace 0

$currentDirectory = split-path $MyInvocation.MyCommand.Definition -parent

$modPath = Join-Path -Path $currentDirectory -ChildPath "PublishIntModule.psm1"
$modFileName = (Get-Item $modPath).BaseName

Remove-Module $modFileName