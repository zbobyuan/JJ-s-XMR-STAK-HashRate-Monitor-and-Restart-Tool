<#	
	.NOTES
	JJ's XMR-STAK HashRate Monitor and Restart Tool

	Based on an idea by @CircusDad on SupportXMR Chat
	His Vega Mining Guide for XMR --> https://vegamining.blogspot.com/

	How many times have you walked away for your computer to come back
	and notice that your hash rate dropped by HUNDREDS of hashes?
	How many times did you wake up to that scenario and wonder how long it had been going on?
	
	What happens when you go away for a few days with your lady/gentleman or some other sexy creature? 
	If you're like me you stress over your rig! It really kills the mood.
	
	How much potential profit have you lost to this terror!
	
	Well, I have felt your pain and decided to sit down and come up with a solution and here it is.
	How much is your peace of mind worth? If you find that your daily hash rate has now increased
	because this is no longer happening to you I'd appreciate it if you would consider a donation
	toward my hard work.
	
	No amount is too small! I'm not greedy! :-)
	
	XMR: 42JFvWHSSGCFUBSwTz522zXrkSuhZ6WnwCFv1mFaokDS7LqfT2MyHW32QbmH3CL94xjXUW8UsQMAj8NFDxaVR8Y1TNqY54W
	
	Purpose:	To monitor the STAK hashrate. If it drops below the threshold,
				the script is restarted.
				
	Features:	Script elevates itself if not run in Admin context.
				Logging
				The Radeon RX Vega driver is disabled/enabled.
				Any tools defined in the "Start Video Card Management Tools Definitions"
				section below are executed in order.
				Sets developer suggested environment variables
				Miner is started.
				Hash rate is monitored.
				If hash rate falls below the target as defined in the $hdiff variable (default is 100 hashes) 
				or STAK stops responding the miner process is killed.
				Script re-starts itself.

	*** IMPORTANT NOTE ***: If the script cannot kill the miner it will stop and wait for input.
							Otherwise it would invoke the miner over and over until the PC ran out of memory.
							In testing I have not seen it fail to kill the miner but I need to account for it.

	Requirements:	Elevated privilege (Run as Administrator)
					Enable Powershell scripts to run.

	Software Requirements:	XMR-STAK.EXE - Other STAK implementations are no longer supported.
							By default the script is configured to use the following software:
							
								XMR-STAK.EXE <-- Don't remark out this one. That would be bad.
								OverdriveNTool.exe
								nvidiasetp0state.exe
								nvidiaInspector.exe
							
							If you do not wish to use some or all of them just REMARK (use a #)
							out the lines below where they are defined in the USER VARIABLES SECTION.
							All executable files must be in the same folder as the script.
							
							
	Configuration: See below in the script for configuration items.

	Usage:	Powershell.exe -ExecutionPolicy Bypass -File JJs_HashMonitor.ps1
	
	Future enhancements under consideration:	SMS/email alerts
												Move settings out of the script and into a simple
												txt file to make it easier to manage them.

	Author:	TheJerichoJones at the Google Monster mail system

	Version: 3.1f
	
	Release Date: 2017-12-03

	Copyright 2017, TheJerichoJones

	License: 
	This program is free software: you can redistribute it and/or modify
	it under the terms of the GNU General Public License version 3 as 
	published by the Free Software Foundation.

	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License
	along with this program.  If not, see <http://www.gnu.org/licenses/>.
#>

######################################################################################
#  !! Scroll down to "USER VARIABLES SECTION"
#  !! There are variables you want to review/modify for your setup
######################################################################################
$ver = "3.1f"
$Host.UI.RawUI.WindowTitle = "JJ's XMR-STAK HashRate Monitor and Restart Tool v $ver"
$Host.UI.RawUI.BackgroundColor = "DarkBlue"

Clear-Host
Write-Host "Starting the Hash Monitor Script..."

Push-Location $PSScriptRoot
######################################################################################
############# STATIC Variables - DO NOT CHANGE ##########################
$ScriptDir = Split-Path $MyInvocation.MyCommand.Path -Parent
$ScriptName = $MyInvocation.MyCommand.Name
$global:runDays = $null
$global:runHours = $null
$global:runMinutes = $null
$global:web = New-Object System.Net.WebClient
$global:maxhash = 0
$global:currHash = 0
$vidTool = @()
########## END STATIC Variables - MAKE NO CHANGES ABOVE THIS LINE #######

######################################################################################
########################### USER VARIABLES SECTION ###################################
######################################################################################

#########################################################################
# Set the REQUIRED variables for your Mining Configuration
#########################################################################
# Read this section carefully or you may end up overclocking your video
# card when you don't want to!! YOU HAVE BEEN WARNED
#########################################################################
$Logfile = "XMR_Restart_$(get-date -f yyyy-MM-dd).log"	# Log what we do, delete or REMARK if you don't want logging
$global:STAKexe = "XMR-STAK.EXE"	# The miner. Expects to be in same folder as this script
#$global:STAKcmdline = "--noNVIDIA"	# STAK arguments. Not required, REMARK out if not needed
$stakIP = '127.0.0.1'	# IP or hostname of the machine running STAK (ALWAYS LOCAL) Remote start/restart of the miner is UNSUPPORTED.
						# !! DON'T FORGET TO ENABLE THE WEBSERVER IN YOUR CONFIG FILE !!
$stakPort = '420'		# Port STAK is listening on

##### Start Video Card Management Tools Definitions
# These will be executed in order prior to the miner
# Create as many as needed
#### Vid Tool 1
$vidTool += 'OverdriveNTool.exe -p1XMR'	# Expects to be in same folder as this script
										# Delete or REMARK if you don't want use it
#### Vid Tool 2
$vidTool += 'nvidiasetp0state.exe'	# Expects to be in same folder as this script
									# Delete or REMARK if you don't want use it
#### Vid Tool 3
$vidTool += 'nvidiaInspector.exe -setBaseClockOffset:0,0,65 -setMemoryClockOffset:0,0,495 -setOverVoltage:0,0 -setPowerTarget:0,110 -setTempTarget:0,0,79'	# Expects to be in same folder as this script
																																							# Delete or REMARK if you don't want use it
##### End VidTools
$global:Url = "http://$stakIP`:$stakPort/api.json" # <-- DO NOT CHANGE THIS !!
#########################################################################
# Set drop trigger and startup timeout
#########################################################################
$hdiff = 100			# This is the drop in total hash rate where we
#						trigger a restart (Starting HASHRATE-$hdiff)
#
$timeout = 60			# (STARTUP ONLY)How long to wait for STAK to
#						return a hashrate before we fail out and
#						restart. There is no limiter on the number of restarts.
#						Press CTRL-C to EXIT
#						
$STAKstable = 120		# How long to wait for the hashrate to stabilize.
#
#########################################################################
###################### END USER DEFINED VARIABLES #######################
#################### MAKE NO CHANGES BELOW THIS LINE ####################

#####  BEGIN FUNCTIONS #####

function call-self 
{
	Start-Process -FilePath "C:\WINDOWS\system32\WindowsPowerShell\v1.0\Powershell.exe" -ArgumentList .\$ScriptName -WorkingDirectory $PSScriptRoot -NoNewWindow
	EXIT
}

Function log-Write
{
	Param ([string]$logstring)
	If ($Logfile)
	{
		Add-content $Logfile -value $logstring
	}
}

function chk-STAKEXE
{
	#####  Look for STAK  #####
	$timeStamp = "{0:yyyy-MM-dd_HH:mm}" -f (Get-Date)
	log-Write ("$timeStamp	$ver	Looking for STAK...")
	Write-Host "Looking for STAK..."
	If (Test-Path $global:STAKexe)
	{
		Write-Host "STAK found! Continuing..."
		log-Write ("$timeStamp	$ver	STAK found! Continuing...")
	}
	Else
	{
		$timeStamp = "{0:yyyy-MM-dd_HH:mm}" -f (Get-Date)
		log-Write ("$timeStamp	$ver	$global:STAKexe NOT FOUND.. EXITING")
		Clear-Host
		Write-Host -fore Red `n`n!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
		Write-Host -fore Red "         $global:STAKexe NOT found. "
        Write-Host -fore Red "   Can't do much without the miner now can you!"
		Write-Host -fore Red "          Now exploding... buh bye!"
		Write-Host -fore Red !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
		wait-ForF12
		$timeStamp = "{0:yyyy-MM-dd_HH:mm}" -f (Get-Date)
		log-Write ("$timeStamp	$ver	=== Script Ended ===")
		Exit
	}
}

function reset-VideoCard {
	###################################
	##### Reset Video Card(s) #####
	##### No error checking
	Write-host "Resetting Video Card(s)..."
	$timeStamp = "{0:yyyy-MM-dd_HH:mm}" -f (Get-Date)
	log-Write ("$timeStamp	$ver	Running Video Card Reset")
	$d = Get-PnpDevice| where {$_.friendlyname -like 'Radeon RX Vega'}
	$vCTR = 0
	foreach ($dev in $d) {
		$vCTR = $vCTR + 1
		Write-host -fore Green "Disabling "$dev.Name '#'$vCTR
		Disable-PnpDevice -DeviceId $dev.DeviceID -ErrorAction Ignore -Confirm:$false | Out-Null
		$timeStamp = "{0:yyyy-MM-dd_HH:mm}" -f (Get-Date)
		log-Write ("$timeStamp	$ver	Disabled $vCTR $dev")
		Start-Sleep -s 3
		Write-host -fore Green "Enabling "$dev.Name '#' $vCTR
		Enable-PnpDevice -DeviceId $dev.DeviceID -ErrorAction Ignore -Confirm:$false | Out-Null
		$timeStamp = "{0:yyyy-MM-dd_HH:mm}" -f (Get-Date)
		log-Write ("$timeStamp	$ver	Enabled $vCTR $dev")
		Start-Sleep -s 3
	}
	$timeStamp = "{0:yyyy-MM-dd_HH:mm}" -f (Get-Date)
	log-Write ("$timeStamp	$ver	$vCTR Video Card(s) Reset")
	Write-host -fore Green $vCTR "Video Card(s) Reset"
}

Function Run-Tools ($app)
{
	foreach ($item in $app)
	{
		$prog = ($item -split "\s", 2)
		if (Test-Path $prog[0])
		{
			Write-host -fore Green "Starting " $prog[0]
			$timeStamp = "{0:yyyy-MM-dd_HH:mm}" -f (Get-Date)
			log-Write ("$timeStamp	$ver	Starting $item ")
			If ($prog[1]) {
				Start-Process -FilePath $prog[0] -ArgumentList $prog[1] | Out-Null
			}
			Else
			{
			Start-Process -FilePath $prog[0] | Out-Null
			}
		Start-Sleep -s 1
		}
		Else
		{
		Write-Host -fore Red $prog[0] NOT found. This is not fatal. Continuing...
		}
	}
}

function start-Mining
{
	#####  Start STAK  #####
	$timeStamp = "{0:yyyy-MM-dd_HH:mm}" -f (Get-Date)
	log-Write ("$timeStamp	$ver	Starting STAK...")
	If (Test-Path $global:STAKexe)
	{
		Write-Host "Starting STAK..."
		If ($STAKcmdline)
		{
			Start-Process -FilePath $ScriptDir\$STAKexe -ArgumentList $STAKcmdline -WindowStyle Minimized
		}
		Else
		{
			Start-Process -FilePath $ScriptDir\$STAKexe
		}
	}
	Else
	{
		$timeStamp = "{0:yyyy-MM-dd_HH:mm}" -f (Get-Date)
		log-Write ("$timeStamp	$ver	$global:STAKexe NOT FOUND.. EXITING")
		Clear-Host
		Write-Host -fore Red `n`n!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
		Write-Host -fore Red "         $global:STAKexe NOT found. "
        Write-Host -fore Red "   Can't do much without the miner now can you!"
		Write-Host -fore Red "          Now exploding... buh bye!"
		Write-Host -fore Red !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
		wait-ForF12
		$timeStamp = "{0:yyyy-MM-dd_HH:mm}" -f (Get-Date)
		log-Write ("$timeStamp	$ver	=== Script Ended ===")
		Exit
	}
}

Function chk-STAK($global:Url) {
	$timeStamp = "{0:yyyy-MM-dd_HH:mm}" -f (Get-Date)
	log-Write ("$timeStamp	$ver	Waiting for STAK HTTP daemon to start")
	Write-host "Waiting for STAK HTTP daemon to start"
	
	$flag = "False"
	$web = New-Object System.Net.WebClient
    $TimeStart = Get-Date -format HH:mm:ss
    $timer = $timeout
	DO {
		Try {
			$result = $web.DownloadString($global:Url)
			$flag = "True"
			}
		Catch {
            $timeEnd = Get-Date -format HH:mm:ss
            $timeDiff = (New-TimeSpan -Start $timeStart -End (Get-Date -format HH:mm:ss)).TotalSeconds
            If ($timeDiff -lt $timeout)
			{
				Write-host -fore Red "STAK not ready... Waiting up to $timer seconds."
				Write-host -fore Red "Press CTRL-C to EXIT NOW"
			}
            If ($timeDiff -gt $timeout)
            {
                $timeout = 0
            }
			Start-Sleep -s 10
            $timer = $timer - 10
			}
		} While (($timeout -gt 1) -And ($flag -eq "False"))
	If ($flag -eq "True")
	{
		Clear-Host
		set-ForegroundWindow | Out-Null
		Write-host -fore Green "`n`n`n## STAK HTTP daemon has started ##`n"
		$timeStamp = "{0:yyyy-MM-dd_HH:mm}" -f (Get-Date)
		log-Write ("$timeStamp	$ver	STAK started successfully")
		
	}
	ElseIf ($flag -eq "False")
	{
		Clear-Host
		Write-host -fore Red "`n`n`n!! Timed out waiting for STAK HTTP daemon to start !!`n"
		start-sleep -s 10
		$timeStamp = "{0:yyyy-MM-dd_HH:mm}" -f (Get-Date)
		log-Write ("$timeStamp	$ver	Timed out waiting for STAK HTTP daemon to start")
		Start-Sleep -s 10
		#Write-Host -NoNewLine "Press any key to EXIT..."
		#$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
		call-Self
		EXIT
	}
	Else
	{
		Clear-Host
		Write-host -fore Red "`n`n`n*** Unknown failure (Daemon failed to start?)... EXITING ***`n"
		start-sleep -s 10
		$timeStamp = "{0:yyyy-MM-dd_HH:mm}" -f (Get-Date)
		log-Write ("$timeStamp	$ver	Unknown failure starting STAK (Daemon failed to start?)")
		Start-Sleep -s 10
		#Write-Host -NoNewLine "Press any key to EXIT..."
		#$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
		$timeStamp = "{0:yyyy-MM-dd_HH:mm}" -f (Get-Date)
		log-Write ("$timeStamp	$ver	=== Script Ended ===")
		call-Self
		EXIT
	}
	
}

function starting-Hash
{
	$timeStamp = "{0:yyyy-MM-dd_HH:mm}" -f (Get-Date)
	log-Write ("$timeStamp	$ver	Waiting for hash rate to stabilize")
	#Write-host -fore Green "Waiting for hash rate to stabilize"

    #$startTestHash = 1
    $global:currTestHash = 0

	$sCTR = 0
	# Wait x seconds for hash rate to stabilize
	while ($STAKstable -gt 0)
	{
		$data = $null
		$total = $null
		$global:currTestHash = $null
		$data = @{}
		$total = @{}
		$rawdata = Invoke-WebRequest -UseBasicParsing -Uri $global:Url -TimeoutSec 60
		If ($rawdata)
		{
			$data = $rawdata | ConvertFrom-Json
			$rawtotal = ($data.hashrate).total
			$total = $rawtotal | foreach {$_}
			$global:currTestHash = $total[0]
			If (!$global:currTestHash -eq [int] -And $sCTR -gt 20)
			{
				Clear-Host
				Write-host -fore Red "`nSTAK is not returning good hash data"
				Write-host -fore Red "`nCurrent Hash = $global:currTestHash"
				Write-host -fore Red "Restarting in 10 seconds"
				$timeStamp = "{0:yyyy-MM-dd_HH:mm}" -f (Get-Date)
				log-Write ("$timeStamp	$ver	Hash Mon Phase: STAK is not returning good data. Current Hash =  $global:currTestHash")
				Start-Sleep -s 10
				$flag = "False"
				#Break
				$timeStamp = "{0:yyyy-MM-dd_HH:mm}" -f (Get-Date)
				log-Write ("$timeStamp	$ver	=== Script Ended ===")
				call-Self
				Exit
			}
			ElseIf ($global:currTestHash -eq 0 -And $sCTR -gt 20)
			{
				Clear-Host
				Write-host -fore Red "`nSTAK seems to have stopped hashing"
				Write-host -fore Red "`nCurrent Hash =  $global:currTestHash"
				Write-host -fore Red "Restarting in 10 seconds"
				$timeStamp = "{0:yyyy-MM-dd_HH:mm}" -f (Get-Date)
				log-Write ("$timeStamp	$ver	Hash Mon Phase: STAK seems to have stopped hashing. Current Hash =  $global:currTestHash")
				Start-Sleep -s 10
				$flag = "False"
				#Break
				$timeStamp = "{0:yyyy-MM-dd_HH:mm}" -f (Get-Date)
				log-Write ("$timeStamp	$ver	=== Script Ended ===")
				call-Self
				Exit
			}
			If (!$startTestHash)
			{
				$startTestHash = $global:currTestHash
			}	

			Clear-Host
			If ($global:currTestHash)
			{
				Write-host -fore Green "`n`nCurrent Hash Rate: $global:currTestHash H/s"
			}
			Write-host -fore Green "`n`nWaiting $STAKstable seconds for hashrate to stabilize."
			Write-host -fore Green "Press CTRL-C to EXIT NOW"
			Start-Sleep -s 1
			$STAKstable = $STAKstable - 1
			$sCTR = $sCTR + 1
		}
		Else
		{
			Clear-Host
			Write-host -fore Red "`nSTAK is not returning array data"
			Write-host -fore Red "Restarting in 10 seconds"
			$timeStamp = "{0:yyyy-MM-dd_HH:mm}" -f (Get-Date)
			log-Write ("$timeStamp	$ver	Stabilization Phase: STAK is not returning array data.")
			Start-Sleep -s 10
			$timeStamp = "{0:yyyy-MM-dd_HH:mm}" -f (Get-Date)
			log-Write ("$timeStamp	$ver	=== Script Ended ===")
			call-Self
			Exit
		}
    }
    If (!$global:currTestHash)
	{
		Clear-Host
		Write-host -fore Green `nCould not get hashrate... restarting
		$timeStamp = "{0:yyyy-MM-dd_HH:mm}" -f (Get-Date)
		log-Write ("$timeStamp	$ver	Stabilization Phase: Could not get hashrate... restarting")
		$timeStamp = "{0:yyyy-MM-dd_HH:mm}" -f (Get-Date)
		log-Write ("$timeStamp	$ver	=== Script Ended ===")
		call-Self
		Exit
	}
	ElseIf ($global:currTestHash -gt $startTestHash)
	{
		$global:maxhash = $global:currTestHash
	}
	Else
    {
		$global:maxhash = $startTestHash
	}

    $global:currHash = $global:currTestHash
	$global:rTarget = ($global:maxhash - $hdiff)
	$timeStamp = "{0:yyyy-MM-dd_HH:mm}" -f (Get-Date)
	log-Write ("$timeStamp	$ver	Hash rate stabilized")
	log-Write ("$timeStamp	$ver	Starting Hashrate: $global:maxhash H/s	Drop Target Hashrate: $global:rTarget H/s hDiff: $hdiff")
}

function current-Hash
{
	# Check our current hashrate against low target every 60 seconds
	Clear-Host
	Write-host -fore Green `nHash monitoring has begun.
	$timer = 0
	$runTime = 0
	$flag = "False"
	$timeStamp = "{0:yyyy-MM-dd_HH:mm}" -f (Get-Date)
	log-Write ("$timeStamp	$ver	Hash monitoring has begun")

	DO
	{
	Try {
		$data = $null
		$total = $null
		$global:currHash = $null
		$data = @{}
		$total = @{}
		Write-host -fore Green `nQuerying STAK...this can take a minute.
		$rawdata = Invoke-WebRequest -UseBasicParsing -Uri $global:Url -TimeoutSec 60
		$flag = "True"
		}
	Catch
		{
			Clear-Host
			Write-host -fore Red "`nWe seem to have lost connectivity to STAK"
			Write-host -fore Red "Restarting in 10 seconds"
			$timeStamp = "{0:yyyy-MM-dd_HH:mm}" -f (Get-Date)
			log-Write ("$timeStamp	$ver	Restarting - Lost connectivity to STAK")
			Start-Sleep -s 10
			$flag = "False"
			#Break
		}
		If ($flag -eq "False")
		{
			Break
		}
		If ($rawdata)
		{
			# Parse JSON data
			$data = $rawdata | ConvertFrom-Json
			# Total Hash
			$rawtotal = ($data.hashrate).total
			$total = $rawtotal | foreach {$_}
			$global:currHash = $total[0]
			If (!$global:currHash -eq [int])
			{
				Clear-Host
				Write-host -fore Red "`nSTAK is not returning good hash data"
				Write-host -fore Red "`nCurrent Hash = $global:currHash"
				Write-host -fore Red "Restarting in 10 seconds"
				$timeStamp = "{0:yyyy-MM-dd_HH:mm}" -f (Get-Date)
				log-Write ("$timeStamp	$ver	Hash Mon Phase: STAK is not returning good data. Current Hash =  $global:currHash")
				Start-Sleep -s 10
				$flag = "False"
				Break
				# Falls through to call-Self
			}
			ElseIf ($global:currHash -eq 0)
			{
				Clear-Host
				Write-host -fore Red "`nSTAK seems to have stopped hashing"
				Write-host -fore Red "`nCurrent Hash =  $global:currHash"
				Write-host -fore Red "Restarting in 10 seconds"
				$timeStamp = "{0:yyyy-MM-dd_HH:mm}" -f (Get-Date)
				log-Write ("$timeStamp	$ver	Hash Mon Phase: STAK seems to have stopped hashing. Current Hash =  $global:currHash")
				Start-Sleep -s 10
				$flag = "False"
				Break
				# Falls through to call-Self
			}
		}
		Else
		{
			Clear-Host
			Write-host -fore Red "`nSTAK is not returning array data"
			Write-host -fore Red "Restarting in 10 seconds"
			$timeStamp = "{0:yyyy-MM-dd_HH:mm}" -f (Get-Date)
			log-Write ("$timeStamp	$ver	Hash Mon Phase: STAK is not returning array data. $rawdata")
			Start-Sleep -s 10
			$flag = "False"
			Break
			# Falls through to call-Self
		}
		# Current difficulty
		$rawdiff = ($data.results).diff_current
		$currDiff = $rawdiff | foreach {$_}
		$global:currDiff = $currDiff[0]
		# Good shares processed
		$rawSharesGood = ($data.results).shares_good
		$SharesGood = $rawSharesGood | foreach {$_}
		$global:GoodShares = $SharesGood[0]
		# Total shares processed
		$rawSharesTotal = ($data.results).shares_total
		$SharesTotal = $rawSharesTotal | foreach {$_}
		$global:TotalShares = $SharesTotal[0]
		# Shares processed time
		$rawSharesTime = ($data.results).avg_time
		$SharesTime = $rawSharesTime | foreach {$_}
		$global:TimeShares = $SharesTime[0]
		# Current Pool
		$global:ConnectedPool = ($data.connection).pool
		# Pool connected uptime
		$rawTimeUp = ($data.connection).uptime
		$rawUpTime = $rawTimeUp | foreach {$_}
		$global:UpTime = $rawUpTime[0]
	
		refresh-Screen
		
		Start-Sleep -s 60
		$timer = ($timer + 60)
		$runTime = ($timer)
	} while ($global:currHash -gt $global:rTarget)
	
	If ($flag -eq "True")
	{
		Clear-Host
		Write-host -fore Red "`n`nHash rate dropped from $global:maxhash H/s to $global:currHash H/s"
		Write-host -fore Red "`nRestarting in 10 seconds"
		$timeStamp = "{0:yyyy-MM-dd_HH:mm}" -f (Get-Date)
		$tFormat =  get-RunTime ($runTime)
		log-Write ("$timeStamp	$ver	Restarting after $tFormat - Hash rate dropped from $global:maxhash H/s to $global:currHash H/s")
		Start-Sleep -s 10
	}
}

function kill-Process ($STAKexe) {
	try
	{
		$prog = ($STAKexe -split "\.", 2)
		$prog = $prog[0]
		# get STAK process
		$stakPROC = Get-Process $prog -ErrorAction SilentlyContinue
		if ($stakPROC) {
			Write-host -fore Red "$prog is running... killing $prog process."
			# try gracefully first
			$stakPROC.CloseMainWindow() | Out-Null
			# kill after five seconds
			Sleep 5
			if (!$stakPROC.HasExited) {
				$stakPROC | Stop-Process -Force | Out-Null
			}
			if (!$stakPROC.HasExited) {
				Write-host -fore Red "Failed to kill the $prog process"
				Write-host -fore Red "`nIf we don't stop here STAK would be invoked"
				Write-host -fore Red "`nover and over until the PC crashed."
				Write-host -fore Red "`n`n That would be very bad."
				Write-host -fore Red 'Press any key to EXIT...';
				$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
				$timeStamp = "{0:yyyy-MM-dd_HH:mm}" -f (Get-Date)
				log-Write ("$timeStamp	$ver	Failed to kill $prog")
				$timeStamp = "{0:yyyy-MM-dd_HH:mm}" -f (Get-Date)
				log-Write ("$timeStamp	$ver	=== Script Ended ===")
				EXIT
			}
			Else
			{
				Write-host -fore Green "Successfully killed the $prog process"
				$timeStamp = "{0:yyyy-MM-dd_HH:mm}" -f (Get-Date)
				log-Write ("$timeStamp	$ver	STAK closed successfully")
			}
		}
		Else
		{
			#Write-host -fore Green "`n$prog process was not found"
			#$timeStamp = "{0:yyyy-MM-dd_HH:mm}" -f (Get-Date)
			#log-Write ("$timeStamp	$ver	$prog process was not found")
		}
	}
	Catch
	{
			Write-host -fore Red "Failed to kill the process $prog"
			Write-host -fore Red "`nIf we don't stop here STAK would be invoked"
			Write-host -fore Red "`nover and over until the PC crashed."
			Write-host -fore Red "`n`n That would be very bad.`n`n"
			wait-ForF12
			$timeStamp = "{0:yyyy-MM-dd_HH:mm}" -f (Get-Date)
			log-Write ("$timeStamp	$ver	Failed to kill $prog")
			$timeStamp = "{0:yyyy-MM-dd_HH:mm}" -f (Get-Date)
			log-Write ("$timeStamp	$ver	=== Script Ended ===")
			EXIT
	}
}

Function refresh-Screen
{
	Clear-Host
	$tmRunTime =  get-RunTime ($runTime)
	$tpUpTime =  get-RunTime ($global:UpTime)
	#Write-Host "=================================================="
	Write-host -fore Green `nStarting Hash Rate:	$global:maxhash H/s 
	Write-host -fore Green `nRestart Target Hash Rate:	$global:rTarget H/s
	Write-host -fore Green `nCurrent Hash Rate: $global:currHash H/s
	Write-host -fore Green `nMonitoring Uptime:	$tmRunTime `n
	Write-Host "=================================================="
	Write-host -fore Green `nPool:	$global:ConnectedPool
	Write-host -fore Green `nPool Uptime:  $tpUpTime
	Write-host -fore Green `nPool Difficulty: $global:currDiff
	Write-host -fore Green `nTotal Shares: $global:TotalShares
	Write-host -fore Green `nGood Shares:	$global:GoodShares
	Write-host -fore Green `nGood Shares %:	(($global:GoodShares / $global:TotalShares) * 100)
	Write-host -fore Green `nShare Time:	$global:TimeShares
	#Write-Host "=================================================="
}

function set-STAKVars
{
	Write-host -fore Green "Setting Env Variables for STAK"
	$timeStamp = "{0:yyyy-MM-dd_HH:mm}" -f (Get-Date)
	log-Write ("$timeStamp	$ver	Setting Env Variables for STAK")

	[System.Environment]::SetEnvironmentVariable("GPU_FORCE_64BIT_PTR", "1", "User")
	[System.Environment]::SetEnvironmentVariable("GPU_MAX_HEAP_SIZE", "99", "User")
	[System.Environment]::SetEnvironmentVariable("GPU_MAX_ALLOC_PERCENT", "99", "User")
	[System.Environment]::SetEnvironmentVariable("GPU_SINGLE_ALLOC_PERCENT", "99", "User")
	
	Write-host -fore Green "Env Variables for STAK have been set"
	$timeStamp = "{0:yyyy-MM-dd_HH:mm}" -f (Get-Date)
	log-Write ("$timeStamp	$ver	Env Variables for STAK have been set")
}

function get-RunTime ($sec)
{
	$myTimeSpan = (new-timespan -seconds $sec)
	If ($sec -ge 3600 -And $sec -lt 86400)
	{ 
		$global:runHours = $myTimeSpan.Hours
		$global:runMinutes = $myTimeSpan.Minutes
		Return "$global:runHours Hours $global:runMinutes Min"
	}
	ElseIf ($sec -ge 86400)
	{
		$global:runDays = $myTimeSpan.Days
		$global:runHours = $myTimeSpan.Hours
		$global:runMinutes = $myTimeSpan.Minutes
		Return "$global:runDays Days $global:runHours Hours $global:runMinutes Min"
	}
	Elseif ($sec -ge 60 -And $sec -lt 3600)
	{
		$global:runMinutes = $myTimeSpan.Minutes
		Return "$global:runMinutes Min"
	}
	Elseif ($sec -lt 60)
	{
		Return "Less than 1 minute"
	}
}

############################## BEGIN ELEVATION #######################################
# If you can't Elevate you're going to have a bad time...
# Elevation code written by: Jonathan Bennett
# License: Not specified
# https://www.autoitscript.com/forum/topic/174609-powershell-script-to-self-elevate/
#
# Test if admin
function Test-IsAdmin() 
{
    # Get the current ID and its security principal
    $windowsID = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $windowsPrincipal = new-object System.Security.Principal.WindowsPrincipal($windowsID)
 
    # Get the Admin role security principal
    $adminRole=[System.Security.Principal.WindowsBuiltInRole]::Administrator
 
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

# Get UNC path from mapped drive
function Get-UNCFromPath
{
   Param(
    [Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
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

 function Resize-Console
{
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
	[CmdletBinding()]
	Param(
		 [Parameter(Mandatory=$False,Position=0)]
		 [int]
		 $Height = 30,
		 [Parameter(Mandatory=$False,Position=1)]
		 [int]
		 $Width = 55
		 )
	$Console = $host.ui.rawui
	$Buffer  = $Console.BufferSize
	$ConSize = $Console.WindowSize

	# If the Buffer is wider than the new console setting, first reduce the buffer, then do the resize
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
}	  

# Relaunch the script if not admin
function Invoke-RequireAdmin
{
    Param(
    [Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
    [System.Management.Automation.InvocationInfo]
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
        $argList += $MyInvocation.BoundParameters.GetEnumerator() | Foreach {"-$($_.Key)", "$($_.Value)"}
        $argList += $MyInvocation.UnboundArguments

        try
        {    
            $process = Start-Process PowerShell.exe -PassThru -Verb Runas -WorkingDirectory $pwd -ArgumentList $argList
            exit $process.ExitCode
        }
        catch {}

        # Generic failure code
        exit 1 
    }
}


function set-ForegroundWindow
{
$user32DLL =  @"
  using System;
  using System.Runtime.InteropServices;
  public class Tricks
  {
	 [DllImport("user32.dll")]
	 [return: MarshalAs(UnmanagedType.Bool)]
	 public static extern bool SetForegroundWindow(IntPtr hWnd);
  }
"@

	Add-Type -TypeDefinition $user32DLL

	$wHandle = (Get-Process -id $pid).MainWindowHandle
	[Tricks]::SetForegroundWindow($wHandle)
}

function wait-ForF12
{
	$continue = $true
	Write-Host "Press F12 to EXIT."
	while($continue)
	{

		if ([console]::KeyAvailable)
		{
			#echo "Press F12";
			$x = [System.Console]::ReadKey() 

			switch ( $x.key)
			{
				F12 { $continue = $false }
			}
			Start-Sleep -s 1
		} 
	}
}


##### END FUNCTIONS #####

##### MAIN - or The Fun Starts Here #####
$ProgressPreference = 'SilentlyContinue'
$timeStamp = "{0:yyyy-MM-dd_HH:mm}" -f (Get-Date)
log-Write ("$timeStamp	$ver	=== Script Started ===")

# Relaunch if not admin
Invoke-RequireAdmin $script:MyInvocation

Resize-Console

set-ForegroundWindow | Out-Null

kill-Process ($STAKexe)

chk-STAKEXE

reset-VideoCard

If ($vidTool) # If $vidTool is defined
{
	Run-Tools ($vidTool) # Run your tools
}

set-STAKVars # Set suggested environment variables

start-Mining # Start mining software

chk-STAK($global:Url) # Wait for STAK to return a hash rate

starting-Hash # Get the starting hash rate

current-Hash # Gather the current hash rate every 60 seconds until it drops beneath the threshold

$timeStamp = "{0:yyyy-MM-dd_HH:mm}" -f (Get-Date)
log-Write ("$timeStamp	$ver	=== Script Ended ===")

$ProgressPreference = 'Continue'

call-Self # Restart the script

##### The End of the World as we know it #####
EXIT
