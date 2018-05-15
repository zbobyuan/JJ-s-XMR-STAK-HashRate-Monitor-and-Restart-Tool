﻿#requires -Version 5.0 -Modules Microsoft.PowerShell.Diagnostics, PnpDevice
Clear-Host
$startattempt=0

Function Run-Miner {
do {
$ver = '4.2.6'
$debug=$false

Push-Location -Path $PSScriptRoot
$Host.UI.RawUI.WindowTitle = "JJ's XMR-STAK HashRate Monitor and Restart Tool v $ver Reworked  by Mutl3y"
$Host.UI.RawUI.BackgroundColor = 'Black'


######################################################################################
############# STATIC Variables - DO NOT CHANGE ##########################
$ScriptDir = (Get-Item -Path '.\' -Verbose).FullName 
$ScriptName = $MyInvocation.MyCommand.Name
$script:runDays = $null
$script:runHours = $null
$script:runMinutes = $null
$script:UpTime = $null
$script:web = New-Object -TypeName System.Net.WebClient
$script:ConnectedPool = $null
$script:TimeShares =$null
$supported_cards=@('Radeon Vega Frontier Edition','Radeon RX 580 Series','Radeon RX Vega')

#Initilisation values, Needed for metrics
$startTestHash = 0
$script:rTarget = 0
$script:maxhash = 0
$script:currHash = 0
$script:sharepercent = 0
$script:currDiff = 0
$script:TotalShares = 0
$script:GoodShares = 0
$script:STAKisup = $false
$script:threadArray = @()

$sleeptime = 5
$stakIP = '127.0.0.1'	# IP or hostname of the machine running STAK (ALWAYS LOCAL) Remote start/restart of the miner is UNSUPPORTED.
$runTime = 0

########## END STATIC Variables - MAKE NO CHANGES ABOVE THIS LINE #######

#########################################################################
# Set the REQUIRED variables for your Mining Configuration              #
#########################################################################

$defaults="  
  # Log Directory
  logdir = logs

  # Logfile
  Logfile = HashMonitor	

  # STAK folder, Seperation for neatness
  STAKdir = xmr-stak

  # The miner. Expects to be in STAKdir folder 
  STAKexe = XMR-STAK.EXE

  # STAK arguments. Not required, REMARK out if not needed
  STAKcmdline = --noNVIDIA	

  # Max attempts at starting STAK before rebooting, only triggers where it hangs on startup, 0 to disable
  STAKMaxStartAttempts = 3

  # !! DON'T FORGET TO ENABLE THE WEBSERVER IN YOUR CONFIG FILE !!
  # Port STAK is listening on
  STAKPort = 420	

  # STAK retry timer, Retry time used in low hash rate if under minimum hash rate, 
  # This can allow recovery before a reset is tried
  retrytimer = 10

  # Height of console, Max 75
  consoleHeight = 25

  # Width of console,  Max 250  
  consoleWidth = 100

  #########################################################################
  # Read this section carefully or you may end up overclocking your video
  # card when you don't want to!! YOU HAVE BEEN WARNED
  #########################################################################
  ##### Start Video Card Management Tools Definitions
  # These will be executed in order prior to the miner
  # Create as many as needed
  #### Vid Tool 1
  _vidTool = OverdriveNTool.exe -consoleonly -r1 -p1XMR
  #_vidTool = OverdriveNTool.exe -consoleonly -r2 -r3  -p2580_low -p3580_low 
  # Delete or REMARK if you don't want use it
  
  #### Vid Tool 2
  #_vidTool = nvidiasetp0state.exe	
  # Delete or REMARK if you don't want use it
  
  #### Vid Tool 3
  #_vidTool = nvidiaInspector.exe -setBaseClockOffset:0,0,65 -setMemoryClockOffset:0,0,495 -setOverVoltage:0,0 -setPowerTarget:0,110 -setTempTarget:0,0,79
  # Delete or REMARK if you don't want use it

  #########################################################################
  # Set drop trigger and startup timeout
  #########################################################################
  # This is the drop in total hash rate where we
  #	trigger a restart (Starting HASHRATE - hdiff)
  hdiff = 300			
  
  # How many seconds to wait for a response from a running instance of XMR-STAK
  runningSTAKtimeout = 2
    
  #	How long to wait for STAK to return a hashrate before we fail out and
  #	restart. There is no limiter on the number of restarts.
  timeout = 60
  
  # 
  STAKmin = 60   
  
  # How to wait before checking for low rates, Allows a low speed check during settling
  # must be greater than the time it takes all your threads to start
  minlowratecheck = 20

  # Enable Vega card resets, Includes RX580's Vega's Vega FE
  CardResetEnabled = True

  # How long to wait for the hashrate to stabilize.
  STAKstable = 60		
  
  # Minimum hashrate 
  minhashrate = 1850	
  
  # Reboot timeout
  rebootTimeout = 10

  # Reboot enabled on driver error
  rebootEnabled = True

  # enable grafana - Only influx udp supported, remember to set default database in influx config file
  grafanaEnabled = True

  # grafana utp url
  grafanaUtpIP = 127.0.0.1

  # grafana utp url
  grafanaUtpPort = 8089      

  # Internet conection wait time
  internetWaitTime = 600


"

#########################################################################
# USER VARIABLES from preferences file                                  #
#########################################################################
$Path = "$ScriptDir\hashmonitor.ini"


# Test for preferences file, create from defaults if missing
IF (!(Test-Path -Path ($Path))){
  Write-Host 'Creating preferences file'
  $defaults | Set-Content -Path $Path 
  Write-host -fore yellow "Please review settings in hashmonitor.ini before re-running,`nBe careful and undervolt your cards, dont overclock its not worth it" 
  Exit
}
    
$inifilevalues = Get-Content -Path $Path |Where-Object {($_.Contains('=')) -notcontains  (($_.Contains('vidTool')))} | Out-String | ConvertFrom-StringData

if ($debug){
  Write-Output -InputObject "Confirming input vars from $Path `n ", $inifilevalues
  Write-Verbose -Message 'Sleeping for 10 seconds' -Verbose
  Start-Sleep -Seconds 10 -Verbose 
}

# Log Directory
if($inifilevalues.Logdir){
  $Logdir= $inifilevalues.Logdir
} else {     $Logdir = 'logs'    }

# Create folder for logfiles
$null = New-Item -ItemType directory -Path $logdir -Force

# Log File  
if($inifilevalues.Logfile){
  $log = $inifilevalues.Logfile
} else {     $Log = 'HashMonitor'   }

# Stak Folder
if($inifilevalues.STAKdir){
  $STAKfolder = $inifilevalues.STAKdir
} else {     $STAKfolder = 'xmr-stak'   }
  
# Stak Executable
if($inifilevalues.STAKexe){
  $stakexe = $inifilevalues.STAKexe
} else {     $stakexe = 'XMR-STAK.EXE'   }
  
  
# Stak STAKStartAttempts
if($inifilevalues.STAKMaxStartAttempts){
  $STAKMaxStartAttempts = $inifilevalues.STAKMaxStartAttempts
} else {     $STAKMaxStartAttempts = 3  }


# Command Line 
if($inifilevalues.STAKcmdline){
  $STAKcmdline = $inifilevalues.STAKcmdline
}
  
# Port STAK is listening on 
if($inifilevalues.STAKPort){
  $STAKPort = [int]$inifilevalues.STAKPort
} else {     $STAKPort = 420 }  
  
# Error retry timer
if ($inifilevalues.retrytimer){
  $script:retrytimer = [int]$inifilevalues.retrytimer
} Else {    $script:retrytimer = 60       }
  
# Console Height
if ($inifilevalues.consoleHeight){
  $consoleHeight = [int]$inifilevalues.consoleHeight 
  Write-Verbose -Message "Console Height, $consoleHeight"
  if ($consoleHeight -gt 75) 
  {
    $consoleHeight = 75
    Write-Host "Console Height, Default MAX used $consoleHeight"
  }
} Else {      $consoleHeight = 30       }
  
# Console Width
if ($inifilevalues.consoleWidth){
  $consoleWidth = [int]$inifilevalues.consoleWidth
  Write-Verbose -Message "Console Width, $consoleWidth"
  if ( $consoleWidth -gt 230 ) 
  {
    $consoleWidth = 230
    Write-Host "Console Width, Default MAX used $consoleWidth"
  }
} Else {      $consoleWidth = 81       } 

if ($inifilevalues.hdiff){
  $hdiff = [int]$inifilevalues.hdiff
} Else {     $hdiff = 300       }

if ($inifilevalues.runningSTAKtimeout){  
  $runningSTAKtimeout = [int]$inifilevalues.runningSTAKtimeout
} Else {     $runningSTAKtimeout = 10       }

if ($inifilevalues.timeout){
  $timeout = [int]$inifilevalues.timeout
} Else {     $timeout = 60       }

if ($inifilevalues.STAKstable){
  $STAKstable = [int]$inifilevalues.STAKstable
} Else {    $STAKstable = 60       } 
  
# Minimum hashrate befor resetting cards	
if ($inifilevalues.minhashrate){
  $minhashrate = [int]$inifilevalues.minhashrate
} Else {    $minhashrate = 60       } 	
  
# Times to wait when reboot triggered
if ($inifilevalues.rebootTimeout){
  $rebootTimeout = [int]$inifilevalues.rebootTimeout
} Else {    $rebootTimeout = 30       } 	
  
# rebootEnabled
if ($inifilevalues.rebootEnabled){
  $rebootEnabled = $inifilevalues.rebootEnabled
} Else {     $rebootEnabled = 'False'       } 	
  
# minlowratecheck
if ($inifilevalues.minlowratecheck){
  $minlowratecheck = $inifilevalues.minlowratecheck
} Else {     $minlowratecheck = 30       } 
  
# CardResetEnabled
if ($inifilevalues.CardResetEnabled){
  $CardResetEnabled = $inifilevalues.CardResetEnabled
} Else {     $CardResetEnabled = 'False'       } 
 
# enable grafana
if ($inifilevalues.grafanaEnabled){
  $grafanaEnabled = $inifilevalues.grafanaEnabled
} Else {     $grafanaEnabled = 'True'       } 

# grafana utp url
if ($inifilevalues.grafanaUtpIP){
  $grafanaUtpIP = $inifilevalues.grafanaUtpIP
} Else {     $grafanaUtpIP = '127.0.0.1'       } 

# grafana utp url
if ($inifilevalues.grafanaUtpPort){
  $grafanaUtpPort = $inifilevalues.grafanaUtpPort
} Else {     $grafanaUtpPort = 8089       } 


# internetWaitTime
if ($inifilevalues.internetWaitTime){
  $internetWaitTime = $inifilevalues.internetWaitTime
} Else {     $internetWaitTime = 600       } 

$logfile =  ("$logdir\$log" +  "_$(get-date -Format yyyy-MM-dd).log") # Log what we do by the day


$script:STAKexe = $stakexe	             # The miner to run 
$script:STAKcmdline = $STAKcmdline	     # STAK arguments
$script:STAKfolder = $STAKfolder         # STAK folder
$script:STAKPort = $STAKPort  
$script:hdiff = $hdiff

$vidToolArray = (Get-Content -Path $Path |
  Where-Object {($_.Contains('_vidTool'))} | 
ForEach-Object {ConvertFrom-StringData -StringData ($_ -replace '\n-\s+')}).Values

ForEach($vidTool2 in $vidToolArray) {
  Write-Verbose -Message "vidTool defined = $vidTool2" 
}
  


##########################################################################
# Set the REQUIRED variables for your Mining Configuration after user vars
##########################################################################
$script:Url = "http://$stakIP`:$script:STAKPort/api.json" # DO NOT CHANGE THIS !!

#####  BEGIN FUNCTIONS #####
Function log-Write {
    param (
  [Parameter(Mandatory,HelpMessage='String')][string]$logstring,
  [Parameter(Mandatory,HelpMessage='Provide colour to display to screen')][string]$fore,
  [switch] $linefeed
)
  $timeStamp = '{0:yyyy-MM-dd HH:mm}' -f (Get-Date)
  if ($fore -ne '0'){
    Write-Host -Fore $fore "$logstring"
  }
  
  If  ($Logfile -and $linefeed)  {
    $Logfile = ($Logfile + '.txt')
    Add-content -Path $Logfile -Value ("`n$timeStamp `t$logstring")
  } elseif ($logfile)  {
    $Logfile = ($Logfile + '.txt')
    Add-content -Path $Logfile -Value ("$timeStamp `t$logstring")
  } 
}

function Invoke-RequireAdmin { Param(
    [Parameter(Position=0, Mandatory, ValueFromPipeline)]
    [Management.Automation.InvocationInfo]
  $MyInvocation)

  if (-not (Test-IsAdmin))
  {
    # Get the script path
    $scriptPath = $MyInvocation.MyCommand.Path
    $scriptPath = Get-UNCFromPath -Path $scriptPath

    # Need to quote the paths in case of spaces
    $scriptPath = '"' + $scriptPath + '"'

    # Build base arguments for powershell.exe
    [string[]]$argList = @('-NoLogo -NoProfile', '-ExecutionPolicy Bypass', '-File', $scriptPath)

    # Add 
    $argList += $MyInvocation.BoundParameters.GetEnumerator() | ForEach-Object {"-$($_.Key)", "$($_.Value)"}
    $argList += $MyInvocation.UnboundArguments

    if ($scriptPath -replace '"' -match '.ps1$'){
    try
    {    
      $process = Start-Process -FilePath PowerShell.exe -PassThru -Verb Runas -WorkingDirectory $pwd -ArgumentList $argList
      exit $process.ExitCode
    }
    catch {
        log-Write 'Failed to elevate to administrator' -fore Red
        EXIT
        }
    } else {
        log-Write 'You need to run this as admin for xmrSTAK tomine efficent blocks' -fore Red
        EXIT
        }

  }
}

function Test-RegistryKeyValue{
  param(
    [Parameter(Mandatory,HelpMessage="The path to the registry key where the value should be set.  Will be created if it doesn't exist.")]
    [string]
    $Path,

    [Parameter(Mandatory)]
    [string]
    # The name of the value being set.
    $Name
  )

  if( -not (Test-Path -Path $Path -PathType Container) )
  {
    return $false
  }

  $properties = Get-ItemProperty -Path $Path 
  if( -not $properties )
  {
    return $false
  }

  $member = Get-Member -InputObject $properties -Name $Name
  if( $member )
  {
    return $true
  }
  else
  {
    return $false
  }

}

function Check-Network {
    $NetworkTimeout = $internetWaitTime
    $ComputerName = 'www.google.co.uk'
    $CheckEvery = 10
    $NetStatus=$false

    log-Write "Checking network connection to $ComputerName" -fore yellow
 
    ## Start the timer
    $timer = [Diagnostics.Stopwatch]::StartNew()
 
    ## Keep in the loop while the $ComputerName is not pingable
    while (-not ($NetStatus) )
        {
        $NetStatus = (Test-Connection -ComputerName $ComputerName -Quiet -Count 1)
        Write-Verbose -Message "Waiting for [$($ComputerName)] to become pingable..."
        ## If the timer has waited greater than or equal to the timeout, throw an exception exiting the loop
        if ($timer.Elapsed.TotalSeconds -ge $NetworkTimeout)
        {       
           throw "Timeout exceeded. Giving up on ping availability to [$ComputerName]"
        }
        ## Stop the loop every $CheckEvery seconds
        if (-not($NetStatus)) {
            log-Write "Connection down: $($timer.Elapsed.ToString("hh\:mm\:ss"))" -fore red
            Start-Sleep -Seconds $CheckEvery
        }
    }
 
    ## When finished, stop the timer
    $timer.Stop()
    Start-Sleep -Seconds 1
}

function reset-VideoCard  {
  ##### Reset Video Card(s) #####
  
  param
  (
    $Force = $false
  )
log-Write -logstring 'Resetting Video Card(s)...' -fore White
  $allCards = Get-PnpDevice| Where-Object {($_.friendlyname -in $supported_cards)}
  $erroredCards = Get-PnpDevice| Where-Object {($_.friendlyname -in $supported_cards) -and ($_.Status -like 'Error')}
  if ($Force) { $d = $allCards } 
    else      { $d = $erroredCards }
  $vCTR = 0
  if ($CardResetEnabled -eq 'True'){
    foreach ($dev in $d) {
      $vCTR = $vCTR + 1
      log-Write -logstring "Disabling $dev" -fore Red
      $null = Disable-PnpDevice -DeviceId $dev.DeviceID -ErrorAction Ignore -Confirm:$false
      Start-Sleep -Seconds 3
    
      log-Write -logstring "Enabling $dev" -fore Blue
      $null = Enable-PnpDevice -DeviceId $dev.DeviceID -ErrorAction Ignore -Confirm:$false
      Start-Sleep -Seconds 3
    }
    log-Write -logstring "$vCTR Video Card(s) Reset" -fore yellow
  } else {
    log-Write -logstring 'Card reset bypassed' -fore red
  }
}

Function Pause-Then-Exit {
  log-Write -logstring 'Pause for user and exit called' -fore Red
  Pause
  EXIT
}

function call-Self {
    $running=$false
    break
}

Function Pause {
  
  param
  (
    [string]
    $Message = 'Press any key to continue . . . '
  )
If ($psISE) {
    # The "ReadKey" functionality is not supported in Windows PowerShell ISE.
 
    $Shell = New-Object -ComObject 'WScript.Shell'
    $null = $Shell.Popup('Click OK to continue.', 0, 'Script Paused', 0)
    Return
  }
 
  Write-Host -NoNewline $Message
 
  $Ignore =
  16,  # Shift (left or right)
  17,  # Ctrl (left or right)
  18,  # Alt (left or right)
  20,  # Caps lock
  91,  # Windows key (left)
  92,  # Windows key (right)
  93,  # Menu key
  144, # Num lock
  145, # Scroll lock
  166, # Back
  167, # Forward
  168, # Refresh
  169, # Stop
  170, # Search
  171, # Favorites
  172, # Start/Home
  173, # Mute
  174, # Volume Down
  175, # Volume Up
  176, # Next Track
  177, # Previous Track
  178, # Stop Media
  179, # Play
  180, # Mail
  181, # Select Media
  182, # Application 1
  183  # Application 2
 
  While ($KeyInfo.VirtualKeyCode -Eq $Null -Or $Ignore -Contains $KeyInfo.VirtualKeyCode) {
    $KeyInfo = $Host.UI.RawUI.ReadKey('NoEcho, IncludeKeyDown')
  }
 
  Write-Host
}

Function refreshSTAK {
  Try {
    $data = $null
    $total = $null
    $data = @{}
    $total = @{}
    Write-Verbose -Message 'Querying STAK...this can take a minute.'
    $rawdata = (Invoke-WebRequest -UseBasicParsing -Uri $script:Url -TimeoutSec 60) -replace '\\', '\\'
    $flag = 'True'   
  }
  Catch
  {
    Clear-Host
    log-Write -logstring 'Restarting in 10 seconds - Lost connectivity to STAK' -fore red
    $script:currHash = 0
    Start-Sleep -Seconds 10
    call-Self
    
    
  }
  If ($flag -eq 'False')
  {
    Break
  }

  $data = $rawdata | ConvertFrom-Json

  # Hashrate Per Thread
  $rawthread = ($data.hashrate).threads
  $threads = @($rawthread | ForEach-Object {$_[0]})
  $script:threadArray = $threads
  
  # Total Hash
  $rawtotal = ($data.hashrate).total
  $total = $rawtotal | ForEach-Object {$_}
  $script:currHash = $total[0]
  # Current difficulty
  $rawdiff = ($data.results).diff_current
  $currDiff = $rawdiff | ForEach-Object {$_}
  $script:currDiff = $currDiff[0]
  # Good shares processed
  $rawSharesGood = ($data.results).shares_good
  $SharesGood = $rawSharesGood | ForEach-Object {$_}
  $script:GoodShares = $SharesGood[0]
  # Total shares processed
  $rawSharesTotal = ($data.results).shares_total
  $SharesTotal = $rawSharesTotal | ForEach-Object {$_}
  $script:TotalShares = $SharesTotal[0]
  # Shares processed time
  $rawSharesTime = ($data.results).avg_time
  $SharesTime = $rawSharesTime | ForEach-Object {$_}
  $script:TimeShares = $SharesTime[0]
  # Share good poercentage
  if ($script:TotalShares -gt 0){ $script:sharepercent = [math]::Round((( $script:GoodShares / $script:TotalShares) * 100),3) }
  # Current Pool
  $script:ConnectedPool = ($data.connection).pool
  # Pool connected uptime
  $rawTimeUp = ($data.connection).uptime
  $rawUpTime = $rawTimeUp | ForEach-Object {$_}
  $script:UpTime = $rawUpTime[0]

}

Function refresh-Screen {
  $tmRunTime =  get-RunTime -sec ($runTime)
  $tpUpTime  =  get-RunTime -sec ($script:UpTime)
  $displayOutput = 
  "
  ===========================================================
  Starting Hash Rate:       $script:maxhash H/s 
  Restart Hash Rate:        $script:rTarget H/s 
  Current Hash Rate:        $script:currHash H/s 
  Minimum Hash Rate:        $minhashrate H/s 
  Monitoring Uptime:        $tmRunTime 
  ===========================================================
  Pool:                     $script:ConnectedPool
  Uptime:                   $tpUpTime
  Difficulty:               $script:currDiff
  Total Shares:             $script:TotalShares
  Good Shares:              $script:GoodShares
  Good Share Percent:       $script:sharepercent
  Share Time:               $script:TimeShares
  ===========================================================
  "

  Clear-Host
  Write-Host -fore Green $displayOutput 
}

Function Run-Tools {  
  param  (
    [Parameter(Mandatory)]
    $app
  )
foreach ($item in $app)
  {
    $prog = ($item -split '\s', 2)
    if (Test-Path -Path $prog[0])
    {
      log-Write -logstring "Starting $item" -fore green 
      If ($prog[1]) {
        $null = Start-Process -FilePath $prog[0] -ArgumentList $prog[1]
      }
      Else
      {
        $null = Start-Process -FilePath $prog[0]
      }
      Start-Sleep -Seconds 1
    }
    Else
    {
      Write-Host -fore Red "$prog[0] NOT found. This is not fatal. Continuing..."
    }
  }
}

function start-Mining {
  #####  Start STAK  #####
  $timeStamp = "{0:yyyy-MM-dd_HH:mm}" -f (Get-Date)
  
  $STAK = "$ScriptDir\$script:STAKfolder\$script:STAKexe"
  If (Test-Path ($STAK))
  {
    log-Write -logstring 'Starting STAK' -fore Yellow
    If ($STAKcmdline)     {
        Write-Host "$STAK $STAKcmdline $ScriptDir\$script:STAKfolder"
        Start-Process -FilePath $STAK -ArgumentList $STAKcmdline -WorkingDirectory $ScriptDir\$script:STAKfolder -WindowStyle Minimized
        }    Else    {
        Write-Host "$STAK $STAKcmdline $ScriptDir\$script:STAKfolder"
        Start-Process -FilePath $STAK -WorkingDirectory $ScriptDir\$script:STAKfolder -WindowStyle Minimized
        }
    }  Else  {
        log-Write "$script:STAKexe NOT FOUND.. EXITING" -fore Red
        Write-Host -fore Red `n`n!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
        Write-Host -fore Red "         $script:STAKexe NOT found. "
        Write-Host -fore Red "   Can't do much without the miner now can you!"
        Write-Host -fore Red '          Now exploding... buh bye!'
        Write-Host -fore Red !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
        Pause-Then-Exit
    }
  Write-Host -fore green "Giving $script:STAKexe 10 seconds to fall over before continuing"
  start-Sleep -Seconds 10
  $prog = ($script:STAKexe -split '\.', 2)
  $prog = $prog[0]
  $stakPROC = Get-Process -Name $prog -ErrorAction SilentlyContinue
    if (-not($stakPROC)) {
        write-host "$prog"
        log-Write 'stak exited abnormally, Run manually and check output' -fore red 
        Pause-Then-Exit
    }
}

function set-STAKVars {
  log-Write -logstring 'Setting Env Variables for STAK' -fore 0

  [Environment]::SetEnvironmentVariable('GPU_FORCE_64BIT_PTR', '1', 'User')
  [Environment]::SetEnvironmentVariable('GPU_MAX_HEAP_SIZE', '99', 'User')
  [Environment]::SetEnvironmentVariable('GPU_MAX_ALLOC_PERCENT', '99', 'User')
  [Environment]::SetEnvironmentVariable('GPU_SINGLE_ALLOC_PERCENT', '99', 'User')
	
  log-Write -logstring 'Env Variables for STAK have been set' -fore 0
}

function get-RunTime {
  
  param
  (
    [Parameter(Mandatory)]
    $sec
  )
$myTimeSpan = (new-timespan -seconds $sec)
  If ($sec -ge 3600 -And $sec -lt 86400)
  { 
    $script:runHours = $myTimeSpan.Hours
    $script:runMinutes = $myTimeSpan.Minutes
    Return "$script:runHours Hours $script:runMinutes Min"
  }
  ElseIf ($sec -ge 86400)
  {
    $script:runDays = $myTimeSpan.Days
    $script:runHours = $myTimeSpan.Hours
    $script:runMinutes = $myTimeSpan.Minutes
    Return "$script:runDays Days $script:runHours Hours $script:runMinutes Min"
  }
  Elseif ($sec -ge 60 -And $sec -lt 3600)
  {
    $script:runMinutes = $myTimeSpan.Minutes
    Return "$script:runMinutes Min"
  }
  Elseif ($sec -lt 60)
  {
    Return 'Less than 1 minute'
  }
}

function Test-IsAdmin() {
  ############################## BEGIN ELEVATION #######################################
  # If you can't Elevate you're going to have a bad time...
  # Elevation code written by: Jonathan Bennett
  # License: Not specified
  # https://www.autoitscript.com/forum/topic/174609-powershell-script-to-self-elevate/
  #
  # Test if admin

  # Get the current ID and its security principal
  $windowsID = [Security.Principal.WindowsIdentity]::GetCurrent()
  $windowsPrincipal = new-object -TypeName System.Security.Principal.WindowsPrincipal -ArgumentList ($windowsID)
 
  # Get the Admin role security principal
  $adminRole=[Security.Principal.WindowsBuiltInRole]::Administrator
 
  # Are we an admin role?
  if ($windowsPrincipal.IsInRole($adminRole))
  {
    $true
  }
  else
  {
    $false
  }
}

function Get-UNCFromPath { Param(
    [Parameter(Position=0, Mandatory, ValueFromPipeline)]
    [String]
  $Path)

  if ($Path.Contains([io.path]::VolumeSeparatorChar)) 
  {
    $psdrive = Get-PSDrive -Name $Path.Substring(0, 1) -PSProvider 'FileSystem'

    # Is it a mapped drive?
    if ($psdrive.DisplayRoot) 
    {
      $Path = $Path.Replace($psdrive.Name + [io.path]::VolumeSeparatorChar, $psdrive.DisplayRoot)
    }
  }

  return $Path
}

function Resize-Console {
  #
  #	.Synopsis
  #	Resets the size of the current console window
  #	.Description
  #	Set-myConSize resets the size of the current console window. By default, it
  #	sets the windows to a height of 40 lines, with a 3000 line buffer, and sets the 
  #	the width and width buffer to 120 characters. 
  #	.Example
  #	Set-myConSize
  #	Restores the console window to 120x40
  #	.Example
  #	Set-myConSize -Height 30 -Width 180
  #	Changes the current console to a height of 30 lines and a width of 180 characters. 
  #	.Parameter Height
  #	The number of lines to which to set the current console. The default is 40 lines. 
  #	.Parameter Width
  #	The number of characters to which to set the current console. Default is 120. Also sets the buffer to the same value
  #	.Inputs
  #	[int]
  #	[int]
  #	.Notes
  #		Author: Charlie Russel
  #		Modified by: TheJerichoJones
  #	 Copyright: 2017 by Charlie Russel
  #			  : Permission to use is granted but attribution is appreciated
  #	   Initial: 28 April, 2017 (cpr)
  #	   ModHist:
  #
  $Height = $consoleHeight
  $Width = $consoleWidth
  $Console = $host.ui.rawui
  $Buffer  = $Console.BufferSize
  $ConSize = $Console.WindowSize

  # If the Buffer is wider than the new console setting, first reduce the buffer, then do the resize
  
  try
  {
    if ($ConSize.Width){
      If ($Buffer.Width -gt $Width -or $Buffer.Height -gt $Height) {
        If ($Buffer.Width -gt $Width ) {
          $ConSize.Width = $Width
        }
        If ($Buffer.Height -gt $Height ) {
          $ConSize.Height = $Height
        }
        $Console.WindowSize = $ConSize
      }
      $Buffer.Width = $Width
  
      $ConSize.Width = $Width
      $Buffer.Height = $Height
      $Console.BufferSize = $Buffer
      $ConSize = $Console.WindowSize
      $ConSize.Width = $Width
      $ConSize.Height = $Height
      $Console.WindowSize = $ConSize
      [console]::CursorVisible=$false
    }
  }
  # NOTE: When you use a SPECIFIC catch block, exceptions thrown by -ErrorAction Stop MAY LACK
  # some InvocationInfo details such as ScriptLineNumber.
  # REMEDY: If that affects you, remove the SPECIFIC exception type [System.Management.Automation.PropertyNotFoundException] in the code below
  # and use ONE generic catch block instead. Such a catch block then handles ALL error types, so you would need to
  # add the logic to handle different error types differently by yourself.
  catch [Management.Automation.PropertyNotFoundException]
  {
    # get error record
    [Management.Automation.ErrorRecord]$e = $_

    # retrieve information about runtime error
    $info = [PSCustomObject]@{
      Exception = $e.Exception.Message
      Reason    = $e.CategoryInfo.Reason
      Target    = $e.CategoryInfo.TargetName
      Script    = $e.InvocationInfo.ScriptName
      Line      = $e.InvocationInfo.ScriptLineNumber
      Column    = $e.InvocationInfo.OffsetInLine
    }
    
    # output information. Post-process collected info, and log info (optional)
    $info
  }

  
}	  

function disable_crossfire {
  $videocards = Get-ChildItem -Path 'hklm:\SYSTEM\ControlSet001\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}' -ErrorAction Ignore | Select-Object -ExpandProperty Name
  $registrychanges = 0
  Foreach ($videocard in $videocards) {
    $cardnumber = ''
    $cardnumber = ($videocard -split '{4d36e968-e325-11ce-bfc1-08002be10318}')[1]
    $cardpath = ''
    $cardpath = Test-RegistryKeyValue -Path "hklm:\SYSTEM\ControlSet001\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}$cardnumber" -Name 'EnableUlps'
    $videocardName =''
    $videocardnamepath = Test-RegistryKeyValue -Path "hklm:\SYSTEM\ControlSet001\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\$cardnumber" -Name 'DriverDesc'
    if ($videocardnamepath -eq 'True') {
      $videocardName = Get-ItemPropertyValue -Name DriverDesc -Path ("hklm:\SYSTEM\ControlSet001\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\$cardnumber") -ErrorAction Ignore                                  
    }

    if ($cardpath -eq 'True' -And $videocardName -like 'Radeon Vega Frontier Edition' ) { 
      Set-ItemProperty -Path "hklm:\SYSTEM\ControlSet001\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}$cardnumber" -Name EnableUlps -Value 0
 
      Set-ItemProperty -Path "hklm:\SYSTEM\ControlSet001\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}$cardnumber" -Name EnableCrossFireAutoLink -Value 0
      $registrychanges++
      Write-Host "$videocardName Registry settings applied, crossfire is disabled"
    } 
  }
}

function Supported-Cards-OK {
    $d = Get-PnpDevice| Where-Object {($_.friendlyname -in $supported_cards) -and ($_.Status -like 'Error')}
    If ($d) 
    { return $false } else { return $true }
    }

Function test-cards(){
   if ( Supported-Cards-OK )
    { 
    Write-Host 'Driver Status is OK' -fore Green
    $flag = 'True'
    } else  { 
        log-Write -logstring 'Driver in error state, Resetting' -fore red 
        reset-VideoCard
        log-write -logstring 'Re-Checking Driver for error status in 5 seconds' -fore Blue
        Start-Sleep -Seconds 5
        write-host 'Gpu OK ' (Supported-Cards-OK)
        if (Supported-Cards-OK)
        {
            Write-Host "GPU's OK" -fore Green 
        } else { 
            Log-Write -logstring "Checking if reboot enabled: $rebootEnabled" -fore Red
            if ($rebootEnabled -eq 'True') 
            {
                log-Write -logstring "Driver in error state, Restart-Computer in $rebootTimeout" -fore red
                Start-Sleep -Seconds $rebootTimeout
                Restart-Computer -Force 
                EXIT
            } else {
                log-Write -logstring 'Reboot not enabled' -fore red
                Pause-Then-Exit
            }
        } # End of device test 
  } # End of driver error 
}

Function quickcheckSTAK {  
  param  ([Parameter(Mandatory)]$script:Url)
  log-Write -logstring 'Quick Check Stak' -fore yellow
  $flag = 'False'
  $web = New-Object -TypeName System.Net.WebClient

  $ts = New-TimeSpan -Seconds $runningSTAKtimeout
  $elapsedTimer = [Diagnostics.Stopwatch]::StartNew()
  DO {
    Try {
      $null = $web.DownloadString($script:Url)
      $flag = 'True'
      $script:STAKisup = $true
    }
    Catch {
      $timeDiff = (($elapsedTimer.Elapsed - $ts).Seconds) -replace '-'
      Write-Host -fore Green -NoNewline $timeDiff
      $script:STAKisup = $false
    }
  } While (($elapsedTimer.Elapsed -lt $ts) -And ($flag -eq 'False'))
  	$elapsedTimer.Stop()
    
  If (-not($script:STAKisup))
  {
    Clear-Host
    kill-Process -STAKexe ($STAKexe)
    reset-VideoCard -force $true
    test-cards
    disable_crossfire
    & "$env:windir\system32\ipconfig.exe" /FlushDNS
    If (!(Supported-Cards-OK)) {reset-VideoCard} 
    If ($vidToolArray) { 
      Run-Tools -app ($vidToolArray)       
    }
    set-STAKVars # Set suggested environment variables
    start-Mining # Start mining software
  }
}

Function chk-STAK {
  param  (
    [Parameter(Mandatory)]
    $script:Url
  )

  $flag = 'False'
  $web = New-Object -TypeName System.Net.WebClient
  $ts = New-TimeSpan -Seconds $timeout
  $elapsedTimer = [Diagnostics.Stopwatch]::StartNew()
  DO {
    Try {
      $null = $web.DownloadString($script:Url)
      $flag = 'True'
    }
    Catch {
        Clear-Host
        $timeDiff = (($elapsedTimer.Elapsed - $ts).Seconds) -replace '-'
        Write-host -fore Red "STAK not ready... Waiting up to $timeDiff seconds."
        Write-host -fore Red 'Press CTRL-C to EXIT NOW'
        Start-Sleep -Seconds 1
    }
  } While (($elapsedTimer.Elapsed -lt $ts) -And ($flag -eq 'False'))
  $elapsedTimer.Stop()

  If ($flag -eq 'True')
  {
    Clear-Host
    log-Write -logstring 'STAK API responding' -fore Green 		
  }
  ElseIf ($flag -eq 'False')
  {
    Clear-Host
    log-Write -logstring '!! Timed out waiting for STAK HTTP daemon to start !!' -fore red
    
    # Check for hanging stak on startup, This can also be caused by setting STAKmin too low
    if (check-Process -exe $script:STAKexe) {
        $startattempt = $startattempt +1
        log-Write -fore red -logstring "Abnormal Stak process seems to have hung on strartup or your STAKmin $STAKmin is too low, attempt $startattempt"
        if ( ($startattempt -ge $STAKMaxStartAttempts ) -and ($STAKMaxStartAttempts -gt 0)) {
            log-write -fore red "Restarting computer in 10 seconds"
            start-sleep -s 10
            Restart-Computer -Force 
        } elseif (($startattempt -ge $STAKMaxStartAttempts ) -and ($STAKMaxStartAttempts -eq 0) ) {
            log-write -froe red "Reboot disabled, stopping here, please investigate STAK startup"
            Pause-Then-Exit
        } else {
            call-self
            } 
            }
  }
  Else
  {
    Clear-Host
    log-Write -logstring 'Unknown failure starting STAK (Daemon failed to start?)' -fore red
    Pause-Then-Exit
  }
}

function check-Process {  
  param  (
    [Parameter(Mandatory)]
    $exe
  )
try
  {
    $prog = ($exe -split '\.', 2)
    $prog = $prog[0]

    # get process
    $app = Get-Process -Name $prog -ErrorAction SilentlyContinue
    if ($app) {
        return $true
    } else { 
        return $false
        }
    } 
catch {return $false}      
      
}



function starting-Hash{
  log-Write -logstring 'Waiting for hash rate to stabilize' -fore Yellow
  $ts = New-TimeSpan -Seconds $STAKstable
  $elapsedTimer = [Diagnostics.Stopwatch]::StartNew()
  $flag = $false
  while (($elapsedTimer.Elapsed -lt $ts)  -And (-Not($flag))) # Wait $STAKstable seconds for hash rate to stabilize
  {
    $currTestHash = 0
    $data = $null
    $total = $null
    $data = @{}
    $total = @{}
    $rawdata = (Invoke-WebRequest -UseBasicParsing -Uri $script:Url -TimeoutSec 60 ) -replace '\\', '\\'
    If ($rawdata)
    {      
      $data = $rawdata | ConvertFrom-Json
      $rawtotal = ($data.hashrate).total
      $total = $rawtotal | ForEach-Object {$_}
      $currTestHash = $total[0]
      If (!$startTestHash) { $startTestHash = $currTestHash }	
      If ($script:STAKisup){ 
        log-Write 'STAK WAS already running, Skipping wait time' -fore Green
        $flag=$true
        BREAK
        }  

      Clear-Host
      If ($currTestHash) { Write-host -fore Green "Current Hash Rate: $currTestHash H/s" }
      $timeDiff = (($elapsedTimer.Elapsed - $ts).Seconds) -replace '-'
      Write-host -fore Green "Waiting $timeDiff seconds for hashrate to stabilize."
      Write-host -fore Red 'Press CTRL-C to EXIT NOW'
      
      $script:currHash=$currTestHash
      if ($currTestHash -gt 0)      {
        # Hashrate Per Thread
        $rawthread = ($data.hashrate).threads
        $threads = @($rawthread | ForEach-Object {$_[0]})
        $script:threadArray = $threads
        grafana
        If (($currTestHash -lt $minhashrate ) -and ($timeDiff -gt $minlowratecheck )) {
          lowratecheck $minlowratecheck
          $flag=$true
        }
      }
    }
    Start-Sleep -Seconds 1
  }
  $elapsedTimer.Stop() 
    
  If (!$currTestHash)  {
    Clear-Host
    log-Write -logstring 'Could not get hashrate... restarting in 3 seconds' -fore Red
    log-Write -logstring "API data from failure `n$rawdata" -fore red
    Start-Sleep -Seconds 3
    call-Self
  }   
  ElseIf ( $currTestHash -gt $startTestHash)    
        {  $script:maxhash = $currTestHash  }     
  Else  { $script:maxhash = $startTestHash    }

  $script:currHash = $currTestHash
  $script:rTarget = ($script:maxhash - $hdiff)
  log-Write -logstring "Starting Hashrate: $script:maxhash H/s	Drop Target Hashrate: $script:rTarget H/s" -fore Green
}

function current-Hash{
  If ($script:rTarget -gt $minhashrate) {$minhashrate = $script:rTarget}
  clear-host
  Write-Verbose -Message "Check our current hashrate against low target every $sleeptime seconds"
  log-Write -logstring 'Hash monitoring has begun.' -fore Green 
  $timer = 0
  $runTime = 0
  $flag = 'False'
  DO
  {
    refreshSTAK 
    refresh-Screen
    grafana
    Start-Sleep -Seconds $sleeptime
    $timer = ($timer + $sleeptime)
    $runTime = ($timer)
  } while ($script:currHash -gt $minhashrate )
	
  If ($script:currHash -lt $minhashrate ) {
    write-host $script:currHash  $minhashrate
    lowratecheck $minhashrate
    }
	
  If (($flag -eq 'True') -And ($script:currHash -lt $minhashrate ))
  {
    $tFormat =  get-RunTime -sec ($runTime)
    log-Write -logstring "Restarting in 10 seconds after $tFormat - Hash rate dropped from $script:maxhash H/s to $script:currHash H/s" -fore Red
    Start-Sleep -Seconds 10
    $script:STAKisup = $false
    kill-Process -STAKexe ($STAKexe)
    call-self 
  }
}

function lowratecheck {
Param (
    [Parameter(Mandatory)]
    [int]
    $ratetocheck
    )

  log-Write -logstring 'Low hash rate check triggered' -fore Red
  $flag = 'False'
  Check-Network # Check we have internet access
  refreshSTAK   # Re-check STAK, Check-Network can be infinate

  $ts = New-TimeSpan -Seconds 60
  $deadTimer = [Diagnostics.Stopwatch]::StartNew()
  # Check if we are connected  to a pool
  while (($script:UpTime -eq 0) -And ($deadTimer.Elapsed -lt $ts)) {
    log-Write -fore red "Conection died, Pausing for up to 60 Seconds for it too recover $(($deadTimer.Elapsed).Seconds)"
    Start-Sleep -Seconds 1
    refreshSTAK  
    $flag = 'True'  
  }
  $deadTimer.stop()

  if ($script:currHash -gt $ratetocheck ) {$flag = 'True'}
  $ts = New-TimeSpan -Seconds $script:retrytimer
  $elapsedTimer = [Diagnostics.Stopwatch]::StartNew()
  
  # Hashdrop testing loop
  While ( (($elapsedTimer.Elapsed -lt $ts).Seconds) -and ($flag -eq 'False') )
  {
    clear-host
    refreshSTAK
    $countdown = (($elapsedTimer.Elapsed -le $ts).Seconds) -replace '-'
    Write-host -fore Red "Hash rate $script:currHash H/s less than set minimum $ratetocheck H/s"
    Write-host -fore Red "Waiting for $countdown seconds for it to recover" 
     
    if ($script:currHash -gt $ratetocheck ) 
    {
      Write-Host -fore Green 'Above min hash rate'
      $flag = 'True'
      break
    } else {
      Write-Host -fore Red 'Below min hash rate'
    } 
    Start-Sleep -Seconds 1 # Itteration wait time
  } 

  if ($flag -eq 'False')
  {     
    $tFormat =  get-RunTime -sec ($runTime)
    log-Write -logstring "Restarting Script after $tFormat - Hash rate $script:currHash H/s less than set minimum $ratetocheck H/s" -fore red
    kill-Process -STAKexe ($STAKexe)
    $script:STAKisup = $false
    if (Supported-Cards-OK) {
        reset-VideoCard -Force $true # Low rate triggered but driver ok, lets force a card reset and exit
    }
    $script:currHash=0    
    call-Self
  } else {refreshSTAK}
}

function kill-Process {  
  param  (
    [Parameter(Mandatory)]
    $STAKexe
  )
try
  {
    $prog = ($STAKexe -split '\.', 2)
    $prog = $prog[0]
    $failureMessage = "
    Failed to kill the process $prog
    If we don't stop here STAK would be invoked over and over until the PC crashed.
    That would be very bad...."

    # get STAK process
    $stakPROC = Get-Process -Name $prog -ErrorAction SilentlyContinue
    if ($stakPROC) {
      # try gracefully first
      $null = $stakPROC.CloseMainWindow()
      # kill after five seconds
      Start-Sleep -Seconds 5
      if (!$stakPROC.HasExited) {
        $null = $stakPROC | Stop-Process -Force
      }
      if (!$stakPROC.HasExited) {
        Write-host -fore Red $failureMessage
        log-Write -logstring "Failed to kill $prog" -fore 0
        Pause-Then-Exit
      }      Else      {        log-Write -logstring 'STAK closed successfully' -fore Green      }
    }    Else     {      log-Write -logstring "$prog process was not found" -Fore Green    }
  }
  Catch
  {
    Write-host -fore Red failureMessage
    log-Write -logstring "Failed to kill $prog" -fore 0
    Pause-Then-Exit
  }
}

Function grafana {    
    if ($grafanaEnabled -eq 'True') {
  $Metrics = @{
    MemoryFree = (Get-Counter -Counter '\Memory\Available MBytes').CounterSamples.CookedValue
    CPU = (Get-Counter -Counter '\Processor(_Total)\% Processor Time').CounterSamples.CookedValue
    Total_Hash_Rate = [int]$script:currHash
    Difficulty = [int]$script:currDiff
    Total_Shares = [int]$script:TotalShares
    Good_Shares =  [int] $script:GoodShares
    Average_time = [int]$script:TimeShares
  }

  # Add in per thread hashrate
  if ($script:threadArray[0])
  {
    $script:threadArray | ForEach-Object -Begin { $seq = 0 } -Process {
      $key = "Thread_$seq"
      $Metrics.add($key,$script:threadArray[$seq])
      $seq++ 
    }
  }  
  
  Write-InfluxUDP -Measure Hashrate -Tags @{Server=$env:COMPUTERNAME} -Metrics $Metrics -IP $grafanaUtpIP -Port $grafanaUtpPort #-Verbose
  }
}

##### END FUNCTIONS #####


##### MAIN - or The Fun Starts Here #####
do {
$ProgressPreference = 'SilentyContinue' # Disable web request progress bar
 
# Display key settings
if ($initalRun)
    {
      log-Write -fore White -linefeed -logstring 'Starting the Hash Monitor Script...' 
      $initalRun = $false
      } 
      Else 
      { log-Write -logstring '============= Loop Started =============' -fore Green }

Log-Write -logstring "Reboot enabled: $rebootEnabled" -fore 'White'
Log-Write -logstring "Reset Cards enabled: $CardResetEnabled" -fore 'White' 
Start-Sleep -Seconds 2


# Relaunch if not admin
Invoke-RequireAdmin -MyInvocation $script:MyInvocation

Resize-Console

Check-Network

quickcheckSTAK  ($script:Url)  # check and start stak if not running

chk-STAK  ($script:Url)        # Wait for STAK to return a hash rate

starting-Hash                  # Get the starting hash rate

current-Hash                   # Gather the current hash rate every $sleeptime seconds until it drops beneath the threshold

 
log-Write -logstring 'Repeat Loop' -fore red

$ProgressPreference = 'Continue'

# End of mining loop
} while ($running -eq $true) # Keep running until restart triggered, triggered in call-Self

    # Setup for next run
    log-Write "Restart triggered`n`n" -fore Red
    $running=$true

} while ($active -eq $true) # Used to exit script from anywhwere in code, ignored in fatal driver error

} # End of Run-Miner Function

# Runtime Variables
$active = $true
$running = $true

# Kick off mining
$initalRun=$true
Run-Miner

