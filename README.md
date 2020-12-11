# AppCrash-Analysis-Suite

AppCrash-Analysis-Suite is a bunch of scripts that will help you to:

 - Enable creation of crash dumps on clients or servers
 - Forward event log entry each time an application crash dump was generated
 - Triggering a PowerShell script that will collect the crash dump to a central server
 - A PowerShell script for automatically analyzing the application crash dump using Windows Debugger


## Enable application crash dumps in Windows
To enable Application dumps in Windows, some registry keys needs to be set on all client computers where you want the dumps to be generated.
If you use the AppCrash-Analysis-Suite in an Active Directory managed environment, the easiest way would be to use Active Directory Group Policy Preferences (GPP).

| Registry-Key | Type | Value |
| -------------| -----| ----- | 
| HKLM\SOFTWARE\Microsoft\Windows\Windows Error Reporting\LocalDumps | 
| HKLM\SOFTWARE\Microsoft\Windows\Windows Error Reporting\LocalDumps\DumpCount|  REG_DWORD|  3
| HKLM\SOFTWARE\Microsoft\Windows\Windows Error Reporting\LocalDumps\DumpType|  REG_DWORD|  0x2
| HKLM\SOFTWARE\Microsoft\Windows\Windows Error Reporting\LocalDumps\DumpFolder| REG_EXPAND_SZ | %\<LOCALAPPDATA\>%\CrashDumps

## Eventlog forwarding
Each time an application crashes and a crash dump is being generated, a new event with Event-Id 1000 (Application Error) will be logged in the Windows Eventlog.
All these events will be forwarded to a central server or workstation where the AppCrash-Analysis-Suite scripts and scheduled tasks are set up.
![enter image description here](https://github.com/michaelmiklis/AppCrash-Analysis-Suite/raw/master/assets/eventlogforward.jpg)

## Scheduled Task
The "Collect-AppCrash.ps1" PowerShell script will be configured as an event-triggered scheduled task. Whenever an eventlog entry with Event-Id 1000 (Application Error) will be forwarded, the PowerShell script will be triggered.
You can specify the directories, etc. using the corrosponding commandline parameters in the scheduled task:

| Parameter | Description 
| -------------| -----|
| -DestinationFolder| Path to folder where to store the app crash dumps
| -EventRecordID | Automatic Parameter using unique EventRecordID| 

## Analyzing crash dumps
Using the PowerShell script "Analyze-AppCrash.ps1" the collected application crash dumps can be automatically analyzed using Windows Debugger (WinDBG). Therefore you need to install Windows Debugging Tools which is part of the Windows SDK:
https://developer.microsoft.com/en-us/windows/downloads/windows-10-sdk

The script will process all crash dumps in the specified directory (*.dmp) and extract the FAILURE_IMAGE_NAME and the PROCESS_NAME. Finally the application crash dump as well as the WinDBG  output will be stored / moved in a new subfolder below the specified dump directory:

![enter image description here](https://github.com/michaelmiklis/AppCrash-Analysis-Suite/raw/master/assets/subfolder.jpg)

This will make it a lot easier to identify the cause or the faulting modules and forward these to the application or module vendor for a bug fix.
