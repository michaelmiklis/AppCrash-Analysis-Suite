######################################################################
## (C) 2019 Michael Miklis (michaelmiklis.de)
##
##
## Filename:      Collect-AppCrash.ps1
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
    [ValidateNotNullOrEmpty()][string]$DestinationFolder,
    [parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()][uint32]$EventRecordID
)

function Collect-AppCrash
{
    <#
        .SYNOPSIS
        The script must be triggered using EventRecordID

        .DESCRIPTION
        The Collect-AppCrash CMDlet can be triggerd by task scheduler to 
        automatically copy the appcrash dump from a remote computer into $DestinationFolder
        It will the anaylze the appcrash using windbg and sort the crashdumps by their causes.

        Currently only german localization is supported. To support other languages
        modify the $EventTemplate object to match the Eventlog language
  
        .PARAMETER DestinationFolder
        A string containing the destination folder where the dumps should be stored 

        .PARAMETER EventRecordID
        EventRecordID of the eventlog entry for which the script was triggered
  
        .EXAMPLE
    
    #>

    param (
        [parameter(Mandatory=$true, ValueFromPipeline=$false)]
        [ValidateNotNullOrEmpty()][string]$DestinationFolder,
        [parameter(Mandatory=$true, ValueFromPipeline=$false)]
        [ValidateNotNullOrEmpty()][uint32]$EventRecordID
    )


    # search event based on EventRecordID
    $XMLQuery = "<QueryList><Query Id=""0"" Path=""ForwardedEvents""><Select Path=""ForwardedEvents""> *[System[EventRecordID={0}]]</Select></Query></QueryList>" -f $EventRecordID

    $Event = Get-WinEvent -FilterXML $XMLQuery

    if (!$Event)
    {
        Write-Error $("Event with EventRecordID={0} not found!" -f $EventRecordID)
        Exit -1
    }

    # convert eventlog entry into PSObject
    $AppCrashObject = $Event | ConvertTo-ApplicationErrorObject


    # check if computer is reachable
    if ((Test-Connection -ComputerName $AppCrashObject.MachineName -Count 1) -eq $false)
    {
        Write-Error $("Remote computer {0} not reachable!" -f $AppCrashObject.MachineName)
        Exit -1
    }

    
    # check if crash dump is accessible - loop through each user profile on remote machine
    foreach ($ProfileFolder in (Get-ChildItem -Path ("\\{0}\c$\Users\" -f $AppCrashObject.MachineName)))
    {

        $AppCrashFound = $false
        $AppCrashFilename = "\\{0}\c$\Users\{1}\AppData\Local\CrashDumps\{2}.{3}.dmp" -f $AppCrashObject.MachineName, $ProfileFolder.Name, $AppCrashObject.ProcessName, $([Convert]::ToInt64($("0x{0}" -f $AppCrashObject.ProcessID),16))

        if ((Test-Path $AppCrashFilename) -eq $true)
        {
            $AppCrashFound = $true

            # exit for-loop
            break
        }
    }

    # build destination filename
    $DestinationFilename = $("{0}_{1}_{2}.{3}.dmp" -f $AppCrashObject.MachineName.Substring(0,$AppCrashObject.MachineName.IndexOf(".")), $EventRecordID, $AppCrashObject.ProcessName, $([Convert]::ToInt64($("0x{0}" -f $AppCrashObject.ProcessID),16)) )


    # if crashdump was not found in a profile
    if (!$AppCrashFound)
    {
       Write-Error "No App crash dump found!"
       "No App crash dump found!" | Out-File -FilePath $(Join-Path -Path $DestinationFolder -ChildPath $($DestinationFilename.Replace(".dmp", ".notfound")))
       Exit -1
    }


    # copy crash dump to destination dir
    Copy-Item -Path $AppCrashFilename -Destination $(Join-Path -Path $DestinationFolder -ChildPath $DestinationFilename)
}


function ConvertTo-ApplicationErrorObject
{
    <#
        .SYNOPSIS
        Converts Event-ID 1000 messages (Application Error) into 
        a PowerShell object containing all properties
        
        .DESCRIPTION
        The ConvertTo-ApplicationErrorObject CMDlet parses a given Application
        Error Event (Event-ID 1000) from the Windows Eventlog into a full
        PowerShell object.
  
        .PARAMETER ApplicationErrorEvent
        A EventLogRecord containing the Event-ID 1000 Error Message
  
        .EXAMPLE
        Get-WinEvent -LogName Application | Where-Object { ($_.ID -eq 1000) -and ($_.ProviderName -eq "Application Error") } | ConvertTo-ApplicationErrorObject | ft *
 
    #>

    param (
        [parameter(Mandatory=$true, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()][System.Diagnostics.Eventing.Reader.EventLogRecord]$ApplicationErrorEvent
    )


    # executes once for each pipeline object
    Process 
    {
        # intialize empty MessageObject
        $MessageObject = [PSCustomObject]@{
            MachineName = $null
            UserId = $null
            TimeCreated = $null
            ProcessName = $null
            ProcessVersion = $null
            ProcessTimestamp = $null
            ModuleName = $null
            ModuleVersion = $null
            ModuleTimestamp = $null
            Exception = $null
            FailureOffset = $null
            ProcessID = $null
            ProcessStartTime = $null
            ProcessPath = $null
            ModulePath = $null
            ReportID = $null
            FullPackageName = $null
            AppID = $null
        }
        

        # Create XML structure of eventlog entry 
        [XML]$eventXML = $event.ToXml() 

        # add properties from event
        $MessageObject.MachineName = $ApplicationErrorEvent.MachineName
        $MessageObject.UserId = $ApplicationErrorEvent.UserId
        $MessageObject.TimeCreated = $ApplicationErrorEvent.TimeCreated


        # 1st line - extract ProcessName
        $MessageObject.ProcessName = $eventXML.Event.EventData.Data[0]

        # 1st line - extract ProcessVersion
        $MessageObject.ProcessVersion = $eventXML.Event.EventData.Data[1]

        # 1st line - extract ProcessTimestamp
        $MessageObject.ProcessTimestamp = $eventXML.Event.EventData.Data[2]

        # 2nd line - extract ModuleName
        $MessageObject.ModuleName = $eventXML.Event.EventData.Data[3]

        # 2nd line - extract ModuleVersion
        $MessageObject.ModuleVersion = $eventXML.Event.EventData.Data[4]

        # 2nd line - extract ModuleTimestamp
        $MessageObject.ModuleTimestamp = $eventXML.Event.EventData.Data[5]

        # 3nd line - extract Exception
        $MessageObject.Exception = $eventXML.Event.EventData.Data[6]

        # 4th line - extract FailureOffset
        $MessageObject.FailureOffset = $eventXML.Event.EventData.Data[7]

        # 5th line - extract ProcessID
        $MessageObject.ProcessID = $eventXML.Event.EventData.Data[8]

        # 6th line - extract ProcessStartTime
        $MessageObject.ProcessStartTime = $eventXML.Event.EventData.Data[9]

        # 7th line - extract ProcessPath
        $MessageObject.ProcessPath = $eventXML.Event.EventData.Data[10]

        # 8th line - extract ModulePath
        $MessageObject.ModulePath = $eventXML.Event.EventData.Data[11]

        # 9th line - extract ReportID
        $MessageObject.ReportID = $eventXML.Event.EventData.Data[12]

        # 10th line - extract FullPackageName
        $MessageObject.FullPackageName = $eventXML.Event.EventData.Data[13]

        # 11th line - extract AppID
        $MessageObject.AppID = $eventXML.Event.EventData.Data[14]

        Write-Output $MessageObject
    }
}

Collect-AppCrash -DestinationFolder $DestinationFolder -EventRecordID $EventRecordID
