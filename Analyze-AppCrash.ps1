######################################################################
## (C) 2019 Michael Miklis (michaelmiklis.de)
##
##
## Filename:      Analyze-AppCrash.ps1
##
## Version:       1.0
##
## Release:       Final
##
## Requirements:  -none-
##
## Description:   
##
## This script is provided 'AS-IS'.  The author does not provide
## any guarantee or warranty, stated or implied.  Use at your own
## risk. You are free to reproduce, copy & modify the code, but
## please give the author credit.
##
####################################################################

param (
    [parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()][string]$DumpFolder,
    [parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()][string]$LogFolder
)


function Analyze-AppCrash
{
    <#
        .SYNOPSIS
        The script processes crash dumps stores in DumpFolder

        .DESCRIPTION
        The Analyze-AppCrash CMDlet analyzes all app crash dumps stored
        in DumpFolder using WinDBG / CDB using !analyze -v. The report will be
        stored in LogFolder. For each dump a folder {PROCESS_NAME}_{FAILURE_MODULE}
        will be generated and the dump + logfile will be moved to that folder.
  
        .PARAMETER DumpFolder
        A string containing the folder where the dumps should are located 

        .PARAMETER LogFolder
        Path to folder where to store the WinDBG report.
  
        .EXAMPLE
        Analyze-AppCrash -DumpFolder "C:\AppCrash-Analysis\Dumps" -LogFolder "C:\AppCrash-Analysis\WinDBG"
    #>

    param (
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()][string]$DumpFolder,
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()][string]$LogFolder
    )

    # check if $DumpFolder contains valid dumps
    $DumpFiles = Get-ChildItem -Path (Join-Path -Path $DumpFolder -ChildPath "*.dmp")

    if (!$DumpFiles)
    {
       Write-Error "No App crash dump found!"
       Exit -1
    }


    # loop for each dump
    foreach ($DumpFile in $DumpFiles)
    {
        $WinDBGLogfile = Join-Path -Path $LogFolder -ChildPath $("{0}.txt" -f $DumpFile.Name) 
        $WinDBGProc = Start-Process -FilePath "C:\Program Files (x86)\Windows Kits\10\Debuggers\x64\cdb.exe" -ArgumentList ("-z", $("""{0}""" -f $DumpFile.FullName), "-c", """!analyze -v; q""", "-logou",$("""{0}""" -f $WinDBGLogfile)) -Wait

        # check if log file was generated
        if (!$(Test-Path -Path $WinDBGLogfile))
        {
            Write-Warning ("Crash Dump {0} cloud not be analyzed" -f $DumpFile.Name)
        }

        # get dump analysis
        $WinDBGLogfileContent = Get-Content -Path $WinDBGLogfile

        $FailureImageName = Select-String -Path $WinDBGLogfile -Encoding unicode -Pattern "FAILURE_IMAGE_NAME" -SimpleMatch
        $ProcessName = Select-String -Path $WinDBGLogfile -Encoding unicode -Pattern "PROCESS_NAME" -SimpleMatch

        if (!$FailureImageName)
        {
             Write-Warning ("Crash Dump {0} does not contain a FAILURE_IMAGE_NAME" -f $DumpFile.Name)
        }

        if (!$ProcessName)
        {
             Write-Warning ("Crash Dump {0} does not contain a PROCESS_NAME" -f $DumpFile.Name)
        }

        $FailureImageName = $FailureImageName.Line.Replace("FAILURE_IMAGE_NAME:  ","")
        $ProcessName = $ProcessName.Line.Replace("PROCESS_NAME:  ","")

        # create directory based on failure image name
        $CrashDumpFolder = Join-Path -Path $DumpFolder -ChildPath $("{0}_{1}" -f $ProcessName, $FailureImageName)

        # create folder if it does not exists
        if (!$(Test-Path -Path $CrashDumpFolder))
        {
             New-Item -ItemType "directory" -Path $CrashDumpFolder
        }

        # move crash dump and logfile into CrashDumpFolder
        Move-Item -Path $WinDBGLogfile -Destination $CrashDumpFolder -Force
        Move-Item -Path $DumpFile -Destination $CrashDumpFolder -Force
    }

}

Analyze-AppCrash -DumpFolder $DumpFolder -LogFolder $LogFolder
