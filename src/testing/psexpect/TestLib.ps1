# Copyright 2009 Adam Geras
# Distributed under the BSD License (See accompanying file license.txt or copy at
# http://www.opensource.org/licenses/bsd-license.php)
set-psdebug -strict -trace 0

# Load the constants and other global vars
&((split-path $MyInvocation.MyCommand.Definition -parent) + "\TestLibConstants.ps1")

# set up aliases for behaviour-driven development
set-alias given invoke-block -scope global
set-alias when invoke-block -scope global
set-alias then invoke-block -scope global

# The root of all the assert* functions.  Evaluates the script block provided it matches
# the regex in $TestConditionFilter.  It will log the test condition in $LogFileName, or
# not at all if $LogFileName is $null.
#
# $LogFileName and 
# $Script, the script block to evaluate
# $Label, the label that identifies the test condition
# $Message, the failure message to use if the assertion does fail
#
function global:Assert-Block([ScriptBlock]$Script, $Label, $Message, $Intent = $Intention.ShouldPass) 
{
    begin {
        function Evaluate-Block([ScriptBlock]$Script, $Label, $Message, $Intent = $Intention.ShouldPass)
        {
            if (!(Test-Path variable:$global:TestConditionFilter)) { $TestConditionFilter = $global:DefaultTestConditionFilter} 
            if ($Label -match $TestConditionFilter) {
                if (!(&$Script))
                {
                    $entry = BuildLogEntry $Intent $ResultPrefix.Failed $Label $Message
                    $Global:TestSuitePassed = $False
                }
                else
                {
                    if ($Intent -eq $Intention.ShouldFail) 
                    {
                        $entry = BuildLogEntry $Intent $ResultPrefix.Passed $Label "Expected 'FAILED' but was 'PASSED'."
                        $Global:TestSuitePassed = $False
                    } else
                    {
                        $entry = BuildLogEntry $Intent $ResultPrefix.Passed $Label
                    }
                }       
        
                # write to the test log provided there is a valid log file name to use, always add to the assertions collection
                $added = $Assertions.Add($entry)
                if ($LogFileName -ne $null) {
                    $logEntry = BuildMessage $entry
                    if (test-path $LogFileName) {
	                    $logEntry | out-file $LogFileName -append -width $LogFileLineLength
	                }
                }
            } 
        }
    }
    process 
    {
        if ($_)
        {
            Evaluate-Block -Script $_ -Label $Label -Message $Message -Intent $Intent 
        }
    }
    end
    {
        if ($Script)
        {
            Evaluate-Block -Script $Script -Label $Label -Message $Message -Intent $Intent
        }
    }
}

# Confirms that an expression evaluates to "true"
function global:Assert($BoolExpr, $Label, $Intent = $Intention.ShouldPass)
{
    Assert-Block {$BoolExpr} -Label $Label -Message $AssertFailedMessage -Intent $Intent
}

# Confirms that the two arguments evaluate to the same values
function global:AssertEqual($Expected, $Actual, $Label, $Intent = $Intention.ShouldPass) 
{
    if (($Expected -eq $null) -and ($Actual -eq $null))
    {
        Assert-Block {$true} -Label $Label -Intent $Intent
    }

    elseif (($Expected -eq $null) -and ($Actual -ne $null))
    {
        $msg = "NULL" + $AssertEqualConjunction + $Actual.ToString()
        Assert-Block {$false} -Label $Label -Message $msg -Intent $Intent
    }

    elseif (($Actual -eq $null) -and ($Expected -ne $null))
    {
        $msg = $Expected.ToString() + $AssertEqualConjunction + "NULL."
        Assert-Block {$false} -Label $Label -Message $msg -Intent $Intent
    }

    else 
    {
        $msg = $Expected.ToString() + $AssertEqualConjunction + $Actual.ToString()
        Assert-Block {$Actual -eq $Expected} -Label $Label -Message $msg -Intent $Intent
    }
}

# Confirms that the two arguments do not evaluate to the same values
function global:AssertNotEqual($Expected, $Actual, $Label, $Intent = $Intention.ShouldPass)
{
    if (($Expected -eq $null) -and ($Actual -eq $null))
    {
        $msg = "Both expected and actual are null."
        Assert-Block {($Actual -ne $Expected)} -Label $Label -Message $msg -Intent $Intent
    }
    elseif (($Expected -eq $null) -and ($Actual -ne $null))
    {
        Assert-Block {$true} -Label $Label -Intent $Intent
    }
    elseif (($Expected -ne $null) -and ($Actual -eq $null))
    {
        Assert-Block {$true} -Label $Label -Intent $Intent
    }
    else
    {
        $msg = $Actual.ToString() + " not expected to be equivalent."
        Assert-Block {($Actual -ne $Expected)} -Label $Label -Message $msg -Intent $Intent
    }
}

#Confirms that two arguments are equal within a tolerance range
function global:AssertInTolerance([double]$Expected, [double]$Actual, [double]$Tolerance, $Label, $Intent = $Intention.ShouldPass)
{
    if ([double]::IsNan($Expected) -or [double]::IsNan($Actual)) 
    {
        Assert-Block {$true} -Label $Label -Message $AssertInToleranceNaNMessage
    }
    elseif (($Expected -eq $null) -or ($Actual -eq $null))
    {
        Assert-Block {$false} -Intent $Intent -Label $Label -Message $AssertInstanceOfNullArgument
    }
    else 
    {
        $tol = [math]::abs($Tolerance)
        $min = $Expected - $tol
        $max = $Expected + $tol
        $msg = $Expected.ToString() + " and " + $Actual.ToString() + $AssertInToleranceConjunction + $tol.ToString() + $AssertInToleranceSuffix
        Assert-Block {(($Actual -ge $min) -and ($Actual -le $max))} -Label $Label -Message $msg -Intent $Intent
    }
}

#Confirms that the specified object is of the specified type
function global:AssertInstanceOf($ExpectedType, $Actual, $Label, $Intent = $Intention.ShouldPass)
{
    if (($Actual -eq $null) -and ($ExpectedType -eq $null))
    {
        $msg = $AssertInstanceOfNullArgument
        Assert-Block {$true} -Label $Label -Message $msg -Intent $Intent
    }
    elseif (($Actual -eq $null) -or ($ExpectedType -eq $null))
    {
        $msg = $AssertInstanceOfNullArgument
        Assert-Block {$false} -Label $Label -Message $msg -Intent $Intent
    }
    else
    {
        $msg = $AssertInstanceOfPrefix + $ExpectedType + $AssertInstanceOfConjunction + $Actual.GetType().FullName
        Assert-Block {($Actual -is $ExpectedType)} -Label $Label -Message $msg -Intent $Intent
    }
}

#Confirms a regex match
# Point of interest - casting the arguments as [string] ensures that they are not equal to $null.
# Hence the comparison of the length to zero instead.  The cast to strings is enforced in order
# to avoid confusion over the argument type - there is a [Regex] that we considered using.
function global:AssertMatch([string]$ContainingString, [string]$RegExpr, $Label, $Intent = $Intention.ShouldPass)
{
    if (([string]::IsNullOrEmpty($ContainingString)) -and ([string]::IsNullOrEmpty($RegExpr)))
    {
        Assert-Block {$true} -Label $Label -Message $null -Intent $Intent
    }
    elseif (([string]::IsNullOrEmpty($ContainingString)) -and (![string]::IsNullOrEmpty($RegExpr)))
    {
        $msg = "String being matched is empty."
        Assert-Block {$false} -Label $Label -Message $msg -Intent $Intent
    }
    elseif ((![string]::IsNullOrEmpty($ContainingString)) -and ([string]::IsNullOrEmpty($RegExpr)))
    {
        $msg = "Regex pattern is empty."
        Assert-Block {$false} -Label $Label -Message $msg -Intent $Intent
    }
    else
    {
        $msg = "No match for " + $RegExpr
        Assert-Block {($ContainingString -match $RegExpr)} -Label $Label -Message $msg -Intent $Intent
    }
}

#Confirms that there is not a regex match
function global:AssertNoMatch([String]$ContainingString, [String]$RegExpr, $Label, $Intent = $Intention.ShouldPass)
{
    if (([string]::IsNullOrEmpty($ContainingString)) -and ([string]::IsNullOrEmpty($RegExpr)))
    {
        $msg = "String to be matched and regex are both empty."
        Assert-Block {$false} -Label $Label -Message $msg -Intent $Intent
    }
    elseif (([string]::IsNullOrEmpty($ContainingString)) -and (![string]::IsNullOrEmpty($RegExpr)))
    {
        Assert-Block {$true} -Label $Label -Intent $Intent
    }
    elseif ((![string]::IsNullOrEmpty($ContainingString)) -and ([string]::IsNullOrEmpty($RegExpr)))
    {
        Assert-Block {$true} -Label $Label -Intent $Intent
    }
    else
    {
        $msg = "Not expecting a match for " + $RegExpr
        Assert-Block{($ContainingString -notmatch $RegExpr)} -Label $Label -Message $msg -Intent $Intent
    }
}

# Confirms that the proposition is null
function global:AssertNull($Proposition, $Label, $Intent = $Intention.ShouldPass)
{
    $msg = $AssertNullFailedMessage
    Assert-Block{($Proposition -eq $null)} -Label $Label -Message $msg -Intent $Intent
}

# Confirms that the proposition is not null
function global:AssertNotNull($Proposition, $Label, $Intent = $Intention.ShouldPass)
{
    $msg = $AssertNotNullFailedMessage
    Assert-Block{($Proposition -ne $null)} -Label $Label -Message $msg -Intent $Intent
}

# Confirms that the two arguments are the same object
function global:AssertSame($Expected, $Actual, $Label, $Intent = $Intention.ShouldPass)
{
    $msg = $AssertSameFailedMessage
    Assert-Block{[System.Object]::ReferenceEquals($Expected, $Actual)} -Label $Label -Message $msg -Intent $Intent
}

# Confirms that the two arguments are not the same object
function global:AssertNotSame($Expected, $Actual, $Label, $Intent = $Intention.ShouldPass)
{
    $msg = $AssertNotSameFailedMessage
    Assert-Block{![System.Object]::ReferenceEquals($Expected, $Actual)} -Label $Label -Message $msg -Intent $Intent
}

# Confirms that a specified exception type was thrown with a specified message that matches a given regular expression
function global:AssertThrows($ExceptionExpected, $MessageExpectedRegExpr, [ScriptBlock]$Script, $Label, $Intent = $Intention.ShouldPass) 
{
    begin
    {
        function Evaluate-Exception($ExceptionExpected, $MessageExpectedRegExpr, [ScriptBlock]$Script, $Label, $Intent = $Intention.ShouldPass) 
        {
            trap
            {
                $lbl = $Label + $AssertThrowsExceptionTypeSuffix
                AssertEqual -Expected $ExceptionExpected -Actual $_.Exception.GetType().FullName  -Label $lbl -Intent $Intent
                $lbl = $Label + $AssertThrowsExceptionMessageSuffix
                AssertMatch -ContainingString $_.Exception.Message -RegExpr $MessageExpectedRegExpr -Label $lbl -Intent $Intent
            }
            if (&$Script) {
                $msg = $AssertThrowsNoExceptionThrownMessage
                Assert-Block -Script {$false} -Label $Label -Message $msg -Intent $Intent
            }
        }
    }

    process
    {
        if ($_)
        {
            Evaluate-Exception -Script $_ -ExceptionExpected $ExceptionExpected -MessageExpectedRegExpr $MessageExpectedRegExpr -Label $Label -Intent $Intent
        }
    }

    end
    {
        if ($Script)
        {
            Evaluate-Exception -Script $Script -ExceptionExpected $ExceptionExpected -MessageExpectedRegExpr $MessageExpectedRegExpr -Label $Label -Intent $Intent
        }
    }
}

# Confirms that a specified script block runs within a certain amount of milliseconds
function global:AssertFaster([Int32]$MaximumTime, [ScriptBlock]$Script, $Label, $Intent = $Intention.ShouldPass)
{
    begin
    {
        function measure-block ([Int32]$MaximumTime, [ScriptBlock]$Script, $Label, $Intent = $Intention.ShouldPass)
        {
            $ActualTime = measure-command $Script
            $msg = $AssertFasterPrefix + $MaximumTime + $AssertFasterConjunction + $ActualTime.TotalMilliseconds + $AssertFasterSuffix
            Assert-Block {($ActualTime.TotalMilliseconds -le $MaximumTime)} -Label $Label -Message $msg -Intent $Intent
        }
    }
    process
    {
        if ($_)
        {
            measure-block -MaximumTime $MaximumTime -Script $_ -Label $Label -Intent $Intent
        }
    }
    end
    {
        if ($Script)
        {
            measure-block -MaximumTime $MaximumTime -Script $Script -Label $Label -Intent $Intent
        }
    }
}

# Confirms membership in an array
function global:AssertContains($Container, $Item, $Label, $Intent = $Intention.ShouldPass)
{
    Assert-Block {$Container -contains $Item} -Label $Label -Message $AssertContainsFailedMessage -Intent $Intent
}

# Always indicates a fail, good for creating a to-do list of failing tests
function global:Fail($Label)
{
    Assert-Block {$false} -Label $Label -Message $FailMessage
}

# Builds a log entry based on the specified message
function global:BuildLogEntry($Intent, $ResultPrefix, $Label, $Message)
{
    $CurrentDate = get-date
    $entry = @{}
    $entry.Add("Timestamp", $CurrentDate.ToString())
    $entry.Add("Intent",$Intent)
    $entry.Add("Result", $ResultPrefix)
    $entry.Add("Label", $Label)
    $entry.Add("Message", $Message)
    return $entry
}

# Build the message to use for the console and/or for the log file
function global:BuildMessage([System.Collections.Hashtable]$TestResult)
{
    if ($TestResult.Message -ne $null) {
        $msg = $TestResult.TimeStamp + $LogFileFieldSeparator + $TestResult.Intent + $LogFileFieldSeparator + $TestResult.Result + $LogFileFieldSeparator + $TestResult.Label + $LogFileFieldSeparator + $TestResult.Message
    } else {
        $msg = $TestResult.TimeStamp + $LogFileFieldSeparator + $TestResult.Intent + $LogFileFieldSeparator + $TestResult.Result + $LogFileFieldSeparator + $TestResult.Label    
    }
    return $msg
}

# Raises the assertions to the console then clears the collection
function global:RaiseAssertions
{
# sayedha: I modified this to return if an error was detected or not
    if (!(Test-Path variable:RaiseAssertionFilter)) { $RaiseAssertionFilter = $DefaultRaiseAssertionFilter} 
 
    $encounteredError = $false   
    for ($a=0; $a -lt $Assertions.Count; $a++) 
    {
        $backColour = $ResultColour.Background
        if (($Assertions[$a].Result + $Assertions[$a].Label) -match $RaiseAssertionFilter)
        {
            $foreColour = GetForegroundColour $Assertions[$a]
            $msg = BuildMessage $Assertions[$a]
            write-host $msg -foregroundcolor $foreColour -backgroundcolor $backColour
            
            if($Assertions[$a].Result -eq $ResultPrefix.Failed) {
                $encounteredError = $true
            }
        }
    }
    $Assertions.Clear() | Out-Null
    
    return !($encounteredError)
}

# Determine the colour of the text on the console based on the intent and the result
function global:GetForegroundColour($decision)
{
    $foreColour = $ResultColour.Success
    if (($decision.Result -eq $ResultPrefix.Failed) -and ($decision.Intent -eq $Intention.ShouldFail))
    {
        $foreColour = $ResultColour.Warning
    } 
    if (($decision.Result -eq $ResultPrefix.Passed) -and ($decision.Intent -eq $Intention.ShouldFail))
    {
        $foreColour = $ResultColour.Error
    } 
    if (($decision.Result -eq $ResultPrefix.Failed) -and ($decision.Intent -eq $Intention.ShouldPass))
    {
        $foreColour = $ResultColour.Error
    }
    
    return $foreColour    
}

# Set the filter (regex) for displayed test results
function global:Set-RaiseAssertionFilter([string]$filter)
{
    $global:RaiseAssertionFilter = $filter
}

# Get the filter (regex) for displayed test results
function global:Get-RaiseAssertionFilter()
{
    return $global:RaiseAssertionFilter
}

# Set the filter (regex) for executed test conditions (asserts)
function global:Set-TestConditionFilter([string]$filter)
{
    $global:TestConditionFilter = $filter
}

# Retrieve the filter (regex) for executed test conditions (asserts)
function global:Get-TestConditionFilter()
{
    return $global:TestConditionFilter
}

function global:Reset-RaiseAssertionFilter()
{
    $global:RaiseAssertionFilter = $global:DefaultRaiseAssertionFilter
}

function global:Reset-TestConditionFilter()
{
    $global:TestConditionFilter = $global:DefaultTestConditionFilter
}

function global:Invoke-Block([string]$Label, [ScriptBlock]$Script)
{
    $entry = BuildLogEntry $Intention.ShouldPass $ResultPrefix.Passed "PSpec" $Label
    # write to the test log provided there is a valid log file name to use, always add to the assertions collection
    $added = $Assertions.Add($entry)
    if ($LogFileName -ne $null) {
        $logEntry = BuildMessage $entry
        if (Test-Path $LogFileName) {
			$logEntry | out-file $LogFileName -append -width $LogFileLineLength
		}
    }
    
    if ($Script)
    {
        &$Script
    }
}