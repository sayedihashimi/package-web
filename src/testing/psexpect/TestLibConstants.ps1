# Copyright 2009 Adam Geras
# Distributed under the BSD License (See accompanying file license.txt or copy at
# http://www.opensource.org/licenses/bsd-license.php)

#region GlobalVariables
set-psdebug -strict -trace 0

# Lists the results of each test condition
$Global:Assertions = new-object System.Collections.Arraylist

# For registering whether or not the test suite passed
# via Kirsten Whitworth - this is set to $False by #Assert-Block if there is an unintentional FAIL
$Global:TestSuitePassed = $True

# TODO: Read log file settings from a configuration file
$Global:LogFileName = "./acceptance-test-log.txt"
$Global:LogFileFieldSeparator = ","
$Global:LogFileLineLength = 240

$Global:_TESTLIB = "_TESTLIB"

# For setting the words that appear for passing and failing test conditions
$Global:ResultPrefix = @{}
    $ResultPrefix.Add("Passed","PASSED")
    $ResultPrefix.Add("Failed","FAILED")

# For setting the colours of the output for various test condition results
$Global:ResultColour = @{}
    $ResultColour.Add("Error","Red")
    $ResultColour.Add("Warning","Yellow")
    $ResultColour.Add("Success","Green")
    $ResultColour.Add("Background","Black")

# For setting the intended result of the test condition evaluation
$Global:Intention = @{}
    $Intention.Add("ShouldPass", "SHOULDPASS")
    $Intention.Add("ShouldFail", "SHOULDFAIL")

$Global:FailMessage = "Intentionally failed."
$Global:AssertFailedMessage = "Specified Boolean expression does not evalute to true."
$Global:AssertNullFailedMessage = "Specified expression is not null."
$Global:AssertInToleranceNaNMessage = "Both expected and actual are NaN."
$Global:AssertInToleranceConjunction = " are expected to be within "
$Global:AssertInToleranceSuffix = " of each other."
$Global:AssertMatchFailedPrefix = "No match for "
$Global:AssertNoMatchFailedPrefix = "Not expecting a match for "
$Global:AssertNotNullFailedMessage = "Specified expression is null."
$Global:AssertSameFailedMessage = "Expected and actual objects are not the same."
$Global:AssertNotSameFailedMessage = "Expected and actual objects are the same."
$Global:AssertThrowsNoExceptionThrownMessage = "No exceptions were thrown by the specified script block."
$Global:AssertThrowsExceptionTypeSuffix = "-ExceptionType"
$Global:AssertThrowsExceptionMessageSuffix = "-ExceptionMessage"
$Global:AssertEqualConjunction = " expected but was "
$Global:AssertContainsFailedMessage = "The list did not contain the specified item."
$Global:AssertFasterPrefix = "Script block expected to run within "
$Global:AssertFasterConjunction = "ms but instead took "
$Global:AssertFasterSuffix = "ms."
$Global:AssertInstanceOfPrefix = "Expected type "
$Global:AssertInstanceOfConjunction = " but is type "
$Global:AssertInstanceOfNullArgument = "One or both of the ExpectedType or Actual objects were null."
$Global:DefaultRaiseAssertionFilter = ".*"
$Global:RaiseAssertionFilter = $Global:DefaultRaiseAssertionFilter

$Global:DefaultTestConditionFilter = ".*"
$Global:TestConditionFilter = $Global:DefaultTestConditionFilter

