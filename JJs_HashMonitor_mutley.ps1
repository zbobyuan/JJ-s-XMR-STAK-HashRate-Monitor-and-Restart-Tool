#requires -Version 5.0 -Modules Microsoft.PowerShell.Diagnostics, PnpDevice
Clear-Host
$startattempt = 0


Function Run-Miner {
	do {
		$ver = '4.3.10'
		$debug = $false
		$script:VerbosePreferenceDefault = 'silentlyContinue'
		Push-Location -Path $PSScriptRoot
		$Host.UI.RawUI.WindowTitle = "JJ's XMR-STAK HashRate Monitor and Restart Tool, Reworked  by Mutl3y v$ver"
		$Host.UI.RawUI.BackgroundColor = 'Black'

		######################################################################################
		############# STATIC Variables - DO NOT CHANGE ##########################
		$ScriptDir = (Get-Item -Path '.\' -Verbose ).FullName
		$ScriptName = $MyInvocation.MyCommand.Name
		$script:runDays = $null
		$script:runHours = $null
		$script:runMinutes = $null
		$script:UpTime = $null
		$script:web = New-Object -TypeName System.Net.WebClient
		$script:ConnectedPool = $null
		$script:TimeShares = $null
		$supported_cards = @('Radeon Vega Frontier Edition', 'Radeon RX 570 Series', 'Radeon RX 580 Series', 'Radeon RX Vega', 'Radeon (TM) RX 470 Graphics', 'Radeon (TM) RX 480 Graphics')

		#Initilisation values, Needed for metrics
		$startTestHash = 0
		$script:rTarget = 0
		$script:maxhash = 0
		$script:currHash = 0
		$script:minhashrate = $null
		$script:sharepercent = 0
		$script:currDiff = 0
		$script:TotalShares = 0
		$script:GoodShares = 0
		$script:STAKisup = $false
		$script:threadArray = @()
		$script:nanopoolLastUpdate = 0
		$script:pools = [Ordered] @{ }
		$script:PoolsList = @{ }
		$script:pools = [Ordered] @{ }
		$script:lastRoomTemp = @{ }
		$script:timeDrift = 999999
		$script:validSensorTime = $null
		$proftStatRefreshTime = 60
		$poolsdottext = "pools.txt"
		$poolsfile = 'pools.json'


		$stakIP = '127.0.0.1'    # IP or hostname of the machine running STAK (ALWAYS LOCAL) Remote start/restart of the miner is UNSUPPORTED.
		$runTime = 0

		########## END STATIC Variables - MAKE NO CHANGES ABOVE THIS LINE #######

		#########################################################################
		# Set the REQUIRED variables for your Mining Configuration              #
		#########################################################################

		$defaults = "

        #
        # $ver Default Configuration file

        # Log Directory
        logdir = logs

        # Logfile
        Logfile = HashMonitor	

        # STAK folder, Seperation for neatness, You should set this ****
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

        # Sleep time in between checks, directly affects grafana metrics
        5

        # Height of console, Max 75
        consoleHeight = 30

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

        # Enable Vega card resets, Includes RX580's, Vega's, Vega FE
        CardResetEnabled = True

        # Force a card reset at startup
        ResetCardOnStartup = True

        # How long to wait for the hashrate to stabilize.
        STAKstable = 60		
  
        # Minimum hashrate 
        minhashrate = 1850	
  
        # Reboot timeout
        rebootTimeout = 10

        # Reboot enabled on driver error
        rebootEnabled = True

        # enable grafana - Only influx udp supported, set default database in influx config file to 'xmrSTAK'
        grafanaEnabled = True

        # grafana utp url
        grafanaUtpIP = 127.0.0.1

        # grafana utp url
        grafanaUtpPort = 8089      

        # Internet conection wait time
        internetWaitTime = 600

        # Notifications
        # Email
        # smsAddress='YOUR SMS eMail address'	# Set YOUR SMS eMail address
        # gUsername='YOUR Gmail eMail address'	# Set YOUR Gmail eMail address
        # gPassword='YOUR Gmail eMail password'	# Set YOUR Gmail eMail password

        # Slack
        # Put your WebHooks URL here,  Default is for this codes Slack space, Usefull if you can allow it to post at least once so I get to see it used out in the wild, your welcome to join and discuss
        slackUrl=https://hooks.slack.com/services/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
        # slackUsername= Defaults to computer name
        # slackChannel='#Hashmonitor'	# Channel to post message. Can be in the format @username or #channel
        # slackEmoji=':clap:'		# Example: :clap:. (Not Mandatory). (if slackEmoji is set, slackIconUrl will not be used)
              # Slack uses the standard emoji codes found at Emoji Cheat Sheet (https://www.webpagefx.com/tools/emoji-cheat-sheet/)
        # slackIconUrl=''			# Url for an icon to use. (Not Mandatory)

        # Verbosoty level for Slack notification,
        # 0 to disable
        # 1 -> 5 Increasing verbosity
        alertLevel = 1

        # How long topause between device resets
        devwait = 3

        # If a device btakes lkonger than this to disabl;e its concidered in error and a reboot is called
        maxDeviceResetTime = 3

        # expectedCards, How many cards should the script see if everythings OK, Do not exceed actual card count
        # Updates on the fly if it finds other cards, this is used as an aditonal trigger for restarting
        installedCards = 1

        # enable nanopool stats if those pools are used, Will auto disable if mining another pool
        enableNanopool = True

        # Refresh rate for Nanopool stats, Please be sensible or you will get blocked,Minimun 60 seconds
        poolStatRefreshRate = 60

        # Estimated pool profitability, minute, day, hour, week, month, Default is day
        coinStats = day

        # How often to check the order of your pools for profitability, Minimum is 60 seconds but it operation its never going to be that low
        # Leaving this at 60 for now during testing expect the default here should be about 20 minutes, It will only be checked during restarts for now
        proftStatRefreshTime = 60

        # Enable profit switching, Please read the ProfitReadme.md before enabling this
        profitSwitching  = False

		# Enable temp reporting and control functions
		#TempWatch = True

		# Main sensor temp file, Works with TEMPer USB devices, Full path
		#sensorDataFile = c:\sensor-data\TEMPerX1.csv

		# Max room Temp, if you use a TEMPer usb temp sensor, This is when we stop mining
		#TEMPerMaxTemp = 30

		# Temp has to drop under max by this much before we start mining again
		#TEMPerMinDiff = 0.2

		# TEMPer Valid Reading Time, Reading has to be within this time period to be concidered valid in case
		# sensor stops responding, Set to huge amount if you do not wish to stop mining on app stop but be careful
		#TEMPerValidMinutes = 2

		# If its too hot do we kill STAK and disable gpu's
		killStakOnMaxTemp = False
      "

		#########################################################################
		# USER VARIABLES from preferences file                                  #
		#########################################################################
		$Path = "$ScriptDir\hashmonitor.ini"


		# Test for preferences file, create from defaults if missing
		IF ( ! (Test-Path -Path ($Path ) ) ) {
			Write-Host 'Creating preferences file'
			$defaults | Set-Content -Path $Path
			Write-host -fore yellow "Please review settings in hashmonitor.ini before re-running,`nBe careful and undervolt your cards, dont overclock its not worth it"
			Exit
		}

		$inifilevalues = (Get-Content -Path $Path |
		                 Where-Object { ($_.Contains( '=' ) ) -notcontains (($_.Contains( 'vidTool' ) ) ) } |
		                 Out-String ) -replace '\\', '\\' |
		                 ConvertFrom-StringData

		if ( $debug ) {
			Write-Output -InputObject "Confirming input vars from $Path `n ", $inifilevalues
			Write-Verbose -Message 'Sleeping for 10 seconds' -Verbose
			Start-Sleep -Seconds 10 -Verbose
		}

		# Log Directory
		if ( $inifilevalues.Logdir ) {
			$Logdir = $inifilevalues.Logdir
		} else {
			$Logdir = 'logs'
		}

		# Create folder for logfiles
		$null = New-Item -ItemType directory -Path $logdir -Force

		# Log File
		if ( $inifilevalues.Logfile ) {
			$log = $inifilevalues.Logfile
		} else {
			$Log = 'HashMonitor'
		}

		# Stak Folder
		if ( $inifilevalues.STAKdir ) {
			$STAKfolder = $inifilevalues.STAKdir
		} else {
			$STAKfolder = 'xmr-stak'
		}

		# Stak Executable
		if ( $inifilevalues.STAKexe ) {
			$stakexe = $inifilevalues.STAKexe
		} else {
			$stakexe = 'XMR-STAK.EXE'
		}


		# Stak STAKStartAttempts
		if ( $inifilevalues.STAKMaxStartAttempts ) {
			$STAKMaxStartAttempts = $inifilevalues.STAKMaxStartAttempts
		} else {
			$STAKMaxStartAttempts = 3
		}


		# Command Line
		if ( $inifilevalues.STAKcmdline ) {
			$STAKcmdline = $inifilevalues.STAKcmdline
		}

		# Port STAK is listening on
		if ( $inifilevalues.STAKPort ) {
			$STAKPort = [int] $inifilevalues.STAKPort
		} else {
			$STAKPort = 420
		}

		# Error retry timer
		if ( $inifilevalues.retrytimer ) {
			$script:retrytimer = [int] $inifilevalues.retrytimer
		} Else {
			$script:retrytimer = 60
		}

		# refresh rate
		if ( $inifilevalues.sleeptime ) {
			$sleeptime = [int] $inifilevalues.sleeptime
		} Else {
			$sleeptime = 5
		}

		# Console Height
		if ( $inifilevalues.consoleHeight ) {
			$consoleHeight = [int] $inifilevalues.consoleHeight
			Write-Verbose -Message "Console Height, $consoleHeight"
			if ( $consoleHeight -gt 75 ) {
				$consoleHeight = 75
				Write-Host "Console Height, Default MAX used $consoleHeight"
			}
		} Else {
			$consoleHeight = 30
		}

		# Console Width
		if ( $inifilevalues.consoleWidth ) {
			$consoleWidth = [int] $inifilevalues.consoleWidth
			Write-Verbose -Message "Console Width, $consoleWidth"
			if ( $consoleWidth -gt 230 ) {
				$consoleWidth = 230
				Write-Host "Console Width, Default MAX used $consoleWidth"
			}
		} Else {
			$consoleWidth = 81
		}

		if ( $inifilevalues.hdiff ) {
			$hdiff = [int] $inifilevalues.hdiff
		} Else {
			$hdiff = 300
		}

		if ( $inifilevalues.runningSTAKtimeout ) {
			$runningSTAKtimeout = [int] $inifilevalues.runningSTAKtimeout
		} Else {
			$runningSTAKtimeout = 10
		}

		if ( $inifilevalues.timeout ) {
			$timeout = [int] $inifilevalues.timeout
		} Else {
			$timeout = 60
		}

		if ( $inifilevalues.devwait ) {
			$devwait = [int] $inifilevalues.devwait
		} Else {
			$devwait = 3
		}

		if ( $inifilevalues.maxDeviceResetTime ) {
			$maxDeviceResetTime = [int] $inifilevalues.maxDeviceResetTime
		} Else {
			$maxDeviceResetTime = 1
		}

		if ( $inifilevalues.STAKstable ) {
			$STAKstable = [int] $inifilevalues.STAKstable
		} Else {
			$STAKstable = 60
		}

		# Minimum hashrate befor resetting cards
		if ( $inifilevalues.minhashrate ) {
			$script:minhashrate = [int] $inifilevalues.minhashrate
		} Else {
			$script:minhashrate = 60
		}

		# Times to wait when reboot triggered
		if ( $inifilevalues.rebootTimeout ) {
			$rebootTimeout = [int] $inifilevalues.rebootTimeout
		} Else {
			$rebootTimeout = 30
		}

		# rebootEnabled
		if ( $inifilevalues.rebootEnabled ) {
			$rebootEnabled = $inifilevalues.rebootEnabled
		} Else {
			$rebootEnabled = 'False'
		}

		# minlowratecheck
		if ( $inifilevalues.minlowratecheck ) {
			$minlowratecheck = $inifilevalues.minlowratecheck
		} Else {
			$minlowratecheck = 30
		}

		# CardResetEnabled
		if ( $inifilevalues.CardResetEnabled ) {
			$CardResetEnabled = $inifilevalues.CardResetEnabled
		} Else {
			$CardResetEnabled = 'False'
		}

		# ResetCardOnStartup
		if ( $inifilevalues.ResetCardOnStartup ) {
			$ResetCardOnStartup = $inifilevalues.ResetCardOnStartup
		} Else {
			$ResetCardOnStartup = 'False'
		}

		# enable grafana
		if ( $inifilevalues.grafanaEnabled ) {
			$grafanaEnabled = $inifilevalues.grafanaEnabled
		} Else {
			$grafanaEnabled = 'True'
		}



		# grafana utp url
		if ( $inifilevalues.grafanaUtpIP ) {
			$grafanaUtpIP = $inifilevalues.grafanaUtpIP
		} Else {
			$grafanaUtpIP = '127.0.0.1'
		}

		# grafana utp url
		if ( $inifilevalues.grafanaUtpPort ) {
			$grafanaUtpPort = $inifilevalues.grafanaUtpPort
		} Else {
			$grafanaUtpPort = 8089
		}


		# internetWaitTime
		if ( $inifilevalues.internetWaitTime ) {
			$internetWaitTime = $inifilevalues.internetWaitTime
		} Else {
			$internetWaitTime = 600
		}

		# Notifications


		# smsAddress='YOUR SMS eMail address'	# Set YOUR SMS eMail address
		if ( $inifilevalues.smsAddress ) {
			$smsAddress = $inifilevalues.smsAddress
		}

		# gUsername='YOUR Gmail eMail address'	# Set YOUR Gmail eMail address
		if ( $inifilevalues.gUsername ) {
			$gUsername = $inifilevalues.gUsername
		}

		# gPassword='YOUR Gmail eMail password'	# Set YOUR Gmail eMail password
		if ( $inifilevalues.gPassword ) {
			$gPassword = $inifilevalues.gPassword
		}

		If ( $smsAddress -and $gUsername -and $gPassword ) {
			$secpasswd = ConvertTo-SecureString $gPassword -AsPlainText -Force
			$gCredentials = New-Object System.Management.Automation.PSCredential ($gUsername, $secpasswd )
		}

		# Slack
		# slackUrl='https://hooks.slack.com/services/xxxxxx'	#Put your WebHooks URL here
		if ( $inifilevalues.slackUrl ) {
			$slackUrl = $inifilevalues.slackUrl
		}

		# slackUsername='JJsHashMonitor'		# Username to send from.
		if ( $inifilevalues.slackUsername ) {
			$slackUsername = $inifilevalues.slackUsername
		} Else {
			$slackUsername = $env:COMPUTERNAME
		}

		# slackChannel='#channel'	# Channel to post message. Can be in the format @username or #channel
		if ( $inifilevalues.slackChannel ) {
			$slackChannel = $inifilevalues.slackChannel
		} Else {
			$slackChannel = "Hashmonitor"
		}

		# slackEmoji=':clap:'		# Example: :clap:. (Not Mandatory). (if $slackEmoji is set, $slackIconUrl will not be used)

		if ( $inifilevalues.slackEmoji ) {
			$slackEmoji = $inifilevalues.slackEmoji
		} Else {
			$slackEmoji = ':white_check_mark:'
		}

		# slackIconUrl=''			# Url for an icon to use. (Not Mandatory)
		if ( $inifilevalues.slackIconUrl ) {
			$slackIconUrl = $inifilevalues.slackIconUrl
		}


		# alertLevel=''			# Verbosity of notifications, Defaults to 1
		if ( $inifilevalues.alertLevel ) {
			$alertLevel = $inifilevalues.alertLevel
		} else {
			$alertLevel = 1
		}

		# enableNanopool= True			# Verbosity of notifications, Defaults to 1
		if ( $inifilevalues.enableNanopool ) {
			$script:enableNanopool = $inifilevalues.enableNanopool
		} else {
			$script:enableNanopool = 'True'
		}

		# poolStatRefreshRate= Default 60, Minimum 60
		if ( $inifilevalues.poolStatRefreshRate ) {
			[int] $poolStatRefreshRate = $inifilevalues.poolStatRefreshRate
			if ( $poolStatRefreshRate -lt 60 ) { $poolStatRefreshRate = 60 }
		} else {
			$poolStatRefreshRate = 60
		}


		if ( $inifilevalues.coinStats ) {
			[string] $coinStats = $inifilevalues.coinStats
		} else {
			$coinStats = 'day'
		}

		# installedCards, how many cards to check for
		if ( $inifilevalues.installedCards ) {
			[int] $installedCards = $inifilevalues.installedCards

		} else {
			$installedCards = 1
		}

		# How often to check profitability
		if ( $inifilevalues.proftStatRefreshTime ) {
			[int] $proftStatRefreshTime = $inifilevalues.proftStatRefreshTime
			if ( $inifilevalues.proftStatRefreshTime -lt 60 ) { $inifilevalues.proftStatRefreshTime = 60 }
		} else {
			$proftStatRefreshTime = 300
		}

		# Check if profitSwitching is enabled
		if ( $inifilevalues.profitSwitching ) {
			[string] $profitSwitching = $inifilevalues.profitSwitching
		} else {
			$profitSwitching = 'False'
		}

		# Check if TEMPerMaxTemp is enabled
		if ( $inifilevalues.TempWatch ) {
			[string] $script:TempWatch = $inifilevalues.TempWatch
		} else { $script:TempWatch = 'False' }

		# Check if TEMPerMaxTemp is enabled
		if ( $inifilevalues.TEMPerMaxTemp ) {
			[Decimal] $TEMPerMaxTemp = $inifilevalues.TEMPerMaxTemp
		}

		# Check if TEMPerMinDiff is enabled
		if ( $inifilevalues.TEMPerMinDiff ) {
			[Decimal] $TEMPerMinDiff = $inifilevalues.TEMPerMinDiff
		}

		# Check if TEMPerValidMinutes is enabled
		if ( $inifilevalues.TEMPerValidMinutes ) {
			[int] $TEMPerValidMinutes = $inifilevalues.TEMPerValidMinutes
		} else { $TEMPerValidMinutes = 0 }


		# Check if sensorDataFile is specified, If not temp setting are disabled
		if ( $inifilevalues.sensorDataFile ) {
			$sensorDataFile = ($inifilevalues.sensorDataFile ) -replace '//', '/'
		}

		# Check if killStakOnMaxTemp is enabled
		if ( $inifilevalues.killStakOnMaxTemp ) {
			[string] $killStakOnMaxTemp = $inifilevalues.killStakOnMaxTemp
		} else { $killStakOnMaxTemp = 'False' }

		$logfile = ("$logdir\$log" + "_$( get-date -Format yyyy-MM-dd ).log" ) # Log what we do by the day


		$script:STAKexe = $stakexe                 # The miner to run
		$script:STAKcmdline = $STAKcmdline         # STAK arguments
		$script:STAKfolder = $STAKfolder         # STAK folder
		$script:STAKPort = $STAKPort
		$script:hdiff = $hdiff

		$script:vidToolArray = (Get-Content -Path $Path |
		                        Where-Object { ($_.Contains( '_vidTool' ) ) } |
		                        ForEach-Object { ConvertFrom-StringData -StringData ($_ -replace '\n-\s+' ) } ).Values

		ForEach ( $vidTool2 in $script:vidToolArray ) {
			Write-Verbose -Message "Global vidTool defined = $vidTool2"
		}


		$poolpath = "$ScriptDir\$script:STAKfolder\pools.txt"
		IF ( Test-Path -Path ($poolpath ) ) {
			$rawcurrency = Get-Content -Path $poolpath |
			               Where-Object { ($_.Contains( 'currency' ) ) -notcontains (($_.Contains( '#' ) ) ) } |
			               Out-String |
			               ConvertFrom-StringData -StringData { ($_ -replace ':', '=' -replace '"|,' ) }
		}

		# Add support for room temp sensor csv, time and reading format with headers
		# Time  Reading
		if ( test-path -path "$PSScriptRoot\TEMPerX1.csv" ) {
			$sensorDataFile = "$PSScriptRoot\TEMPerX1.csv"
		} ElseIf (test-path -path "$PSScriptRoot\sensor-data\TEMPerX1.csv") {
			$sensorDataFile = "$PSScriptRoot\sensor-data\TEMPerX1.csv"
		} ElseIf (Test-Path -Path ".\sensor-data\TEMPerX1.csv") {
			$sensorDataFile = ".\sensor-data\TEMPerX1.csv"
		}


		##########################################################################
		# Set the REQUIRED variables for your Mining Configuration after user vars
		##########################################################################
		$script:Url = "http://$stakIP`:$script:STAKPort/api.json" # DO NOT CHANGE THIS !!

		#####  BEGIN FUNCTIONS #####
		Function log-Write {
			param ([ Parameter ( Mandatory, HelpMessage = 'String' ) ][ string ]$logstring,
			       [ Parameter ( Mandatory, HelpMessage = 'Provide colour to display to screen' ) ][ string ]$fore,
			       [ switch ] $linefeed, [ Parameter ( Mandatory = $true ) ][ int ] $notification

			)
			$timeStamp = (get-Date -format r )
			if ( $fore -ne '0' ) {
				Write-Host -Fore $fore "$logstring"
			}

			If ( $Logfile -and $linefeed ) {
				$Logfile = ($Logfile + '.txt' )
				Add-content -Path $Logfile -Value ("`n$timeStamp `t$logstring" )
			} elseif ($logfile) {
				$Logfile = ($Logfile + '.txt' )
				Add-content -Path $Logfile -Value ("$timeStamp `t$logstring" )
			}

			$msgText = "$timeStamp`t  $logstring"
			if ( $alertLevel -ge $notification ) {
				If ( ($smsAddress ) -and ($notification -eq 0 ) ) {
					Send-MailMessage -From $gUsername -Subject $msgText -To $smsAddress -UseSSL -Port 587 -SmtpServer smtp.gmail.com -Credential $gCredentials
				}
				If ( $slackUrl ) {
					Send-SlackMessage $msgText, $slackUrl, $slackUsername, $slackChannel, $slackEmoji, $slackIconUrl
				}
			}
		}

		function Get-Nanopool-Metric {

			[ OutputType ( [ int ] ) ]
			Param
			(# Which coin to check
				[ Parameter ( Mandatory, HelpMessage = 'You must specify a coin',
				              ValueFromPipelineByPropertyName ) ]
				[ string ]
				$coin,

			# Over how many hours
			#[Parameter(Mandatory=$true)][int]
				[ int ]
				$Xhrs,

			# Operation to be performed
				[ Parameter ( Mandatory = $true ) ][ string ]
				$op,

			# Hashrate to use in calculations
				[ decimal ]
				$hashrate,

			# Offset to use
				[ int ]
				$offset,

			# Count
				[ int ]
				$count
			)


			DynamicParam {
				# Create a parameter dictionary
				$paramDictionary = New-Object -TypeName System.Management.Automation.RuntimeDefinedParameterDictionary

				# Check if op needs as wallet address
				if ( ($op -notin ('approximated_earnings', 'block_stats', 'blocks', 'network_avgblocktime', 'network_lastblocknumber', 'network_timetonextepoch', 'pool_activeminers', 'pool_activeworkers', 'pool_hashrate', 'pool_topminers', 'prices' ) -and ($op ) ) ) {
					Write-Verbose -Message ('wallet check {0}' -f $op )
					$walletattribute = New-Object -TypeName System.Management.Automation.ParameterAttribute
					#$walletattribute.Position = 6
					$walletattribute.Mandatory = $true
					$walletattribute.HelpMessage = 'I need a wallet address for this'

					#create an attributecollection object for the attribute we just created.
					$attributeCollection = new-object -TypeName System.Collections.ObjectModel.Collection[ System.Attribute ]

					#add our custom attribute
					$attributeCollection.Add( $walletattribute )

					#add our paramater specifying the attribute collection
					$walletparam = New-Object -TypeName System.Management.Automation.RuntimeDefinedParameter -ArgumentList ('wallet', [string] , $attributeCollection )

					#expose the name of our parameter
					$paramDictionary.Add( 'wallet', $walletparam )
				}

				# Check if op needs a worker address
				if ( ($op -in ('avghashrateworker', 'avghashratelimited', 'avghashrateworkers', 'hashratechart', 'history', 'pool_activeworkers', 'reportedhashrate', 'shareratehistory', 'workers' ) ) ) {
					Write-Verbose -Message ('Worker check {0}' -f $op )
					#create a new ParameterAttribute Object
					$workerattribute = New-Object -TypeName System.Management.Automation.ParameterAttribute
					#$workerattribute.Position = 7
					$workerattribute.Mandatory = $true
					$workerattribute.HelpMessage = 'I need a worker name for this'

					#create an attributecollection object for the attribute we just created.
					$attributeCollection = new-object -TypeName System.Collections.ObjectModel.Collection[ System.Attribute ]

					#add our custom attribute
					$attributeCollection.Add( $workerattribute )

					#add our paramater specifying the attribute collection
					$workerparam = New-Object -TypeName System.Management.Automation.RuntimeDefinedParameter -ArgumentList ('worker', [string] , $attributeCollection )

					#expose the name of our parameter
					$paramDictionary.Add( 'worker', $workerparam )


				}

				return $paramDictionary
			}

			Begin {
				if ( $PSBoundParameters.wallet ) { $wallet = $PSBoundParameters.wallet }
				if ( $PSBoundParameters.worker ) { $worker = $PSBoundParameters.worker }
				#Write-Verbose -Message "Nanopool API for $coin $op $wallet $worker"
				$null = 'True'

				# Select Operation
				$stat = switch ( $op ) {
					'accountexist'             { ('accountexist/{0}' -f $wallet ) }
					'approximated_earnings'    { ('approximated_earnings/{0}' -f $hashrate ) }
					'avghashrate'              { ('avghashrate/{0}' -f $wallet ) }
					'avghashrateworker'        { ('avghashrate/{0}/{1}' -f $wallet, $worker ) }
					'avghashratelimited'       { ('avghashratelimited/{0}/{1}/{2}' -f $wallet, $worker, $Xhrs ) }
					'avghashratelimited'       { ('avghashratelimited/{0}/{1}' -f $wallet, $Xhrs ) }
					'avghashrateworkers'       { ('avghashrateworkers/{0}' -f $wallet ) }
					'balance'                  { ('balance/{0}' -f $wallet ) }
					'balance_hashrate'         { ('balance_hashrate/{0}' -f $wallet ) }
					'balance_unconfirmed'      { ('balance_unconfirmed/{0}' -f $wallet ) }
					'block_stats'              { ('block_stats/{0}/{1}' -f $offset, $count ) }
					'blocks'                   { ('blocks/{0}/{1}' -f $offset, $count ) }
					'hashrate'                 { ('hashrate/{0}' -f $wallet ) }
					'hashratechart'            { ('hashratechart/{0}/{1}' -f $wallet, $worker ) }
					'hashratechart'            { ('hashratechart/{0}' -f $wallet ) }
					'history'                  { ('history/{0}' -f $wallet ) }
					'history'                  { ('history/{0}/{1}' -f $wallet, $worker ) }
					'network_avgblocktime'     { 'network/avgblocktime' }
					'network_lastblocknumber'  { 'network/lastblocknumber' }
					'network_timetonextepoch'  { 'network/timetonextepoch' }
					'payments'                 { ('payments/{0}' -f $wallet ) }
					'paymentsday'              { ('paymentsday/{0}' -f $wallet ) }
					'pool_activeminers'        { 'pool/activeminers' }
					'pool_activeworkers'       { 'pool/activeworkers' }
					'pool_hashrate'            { 'pool/hashrate' }
					'pool_topminers'           { 'pool/topminers' }
					'prices'                   { 'prices' }
					'reportedhashrate'         { ('reportedhashrate/{0}' -f $wallet ) }
					'reportedhashrate'         { ('reportedhashrate/{0}/{1}' -f $wallet, $worker ) }
					'reportedhashrates'        { ('reportedhashrates/{0}' -f $wallet ) }
					'shareratehistory'         { ('shareratehistory/{0}' -f $wallet ) }
					'shareratehistory'         { ('shareratehistory/{0}/{1}' -f $wallet, $worker ) }
					'shareratehistory'         { ('shareratehistory/{0}/{1}' -f $wallet, $Xhrs ) }
					'user'                     { ('user/{0}' -f $wallet ) }
					'usersettings'             { ('usersettings/{0}' -f $wallet ) }
					'workers'                  { ('workers/{0}' -f $wallet ) }
					default                    { 'prices' }
				}
				$timeStamp = '{0:yyyy-MM-dd_HH:mm}' -f (Get-Date )
			}

			Process {
				Try {
					$data = $null
					$null = $null
					$data = @{ }
					$rawdata = Invoke-WebRequest -UseBasicParsing -Uri $url/$coin/$stat -TimeoutSec 60
					$null = 'True'
					Write-Verbose -Message ("{0}`t Nanopool API call  `n{1}/{2}/{3} `n{4}" -f $timeStamp, $url, $coin, $stat, $rawdata ) #-verbose
				}
				Catch {

					Write-Verbose -Message ("{0}`t Nanopool issue with API call `n{1}/{2}/{3} `n{4}" -f $timeStamp, $url, $coin, $stat, $rawdata ) #-Verbose
					$null = 'False'
				}
			}

			End {
				$data = $rawdata | ConvertFrom-Json
				return $data
			}
		}


		function Send-SlackMessage {
			$slackBody = @{ text = $msgText; channel = $slackChannel; username = $slackUsername; icon_emoji = $slackEmoji; icon_url = $slackIconUrl } |
			             ConvertTo-Json
			try {
				$null = Invoke-WebRequest -UseBasicParsing -Method Post -Uri $slackUrl -Body $slackBody
			}
			Catch {
				Write-Host -fore red "Slack message post failure $slackUrl"
				Write-Host -fore Red "$slackBody"
				Invoke-WebRequest -UseBasicParsing -Method Post -Uri $slackUrl -Body $slackBody #-Verbose
			}
		}

		function Invoke-RequireAdmin {
			Param ([ Parameter ( Position = 0, Mandatory, ValueFromPipeline ) ]
			       [ Management.Automation.InvocationInfo ]
			       $MyInvocation
			)

			if ( -not (Test-IsAdmin ) ) {
				# Get the script path
				$scriptPath = $MyInvocation.MyCommand.Path
				$scriptPath = Get-UNCFromPath -Path $scriptPath

				# Need to quote the paths in case of spaces
				$scriptPath = '"' + $scriptPath + '"'

				# Build base arguments for powershell.exe
				[string[ ]] $argList = @('-NoLogo -NoProfile', '-ExecutionPolicy Bypass', '-File', $scriptPath)

				# Add
				$argList += $MyInvocation.BoundParameters.GetEnumerator() |
				            ForEach-Object { "-$( $_.Key )", "$( $_.Value )" }
				$argList += $MyInvocation.UnboundArguments

				if ( $scriptPath -replace '"' -match '.ps1$' ) {
					try {
						$process = Start-Process -FilePath PowerShell.exe -PassThru -Verb Runas -WorkingDirectory $pwd -ArgumentList $argList
						exit $process.ExitCode
					}
					catch {
						log-Write -logstring 'Failed to elevate to administrator' -fore Red -notification 0
						EXIT
					}
				} else {
					log-Write -logstring 'You need to run this as admin for xmrSTAK tomine efficent blocks' -fore Red -notification 0
					EXIT
				}

			}
		}

		function Test-RegistryKeyValue {
			param (
				[ Parameter ( Mandatory,
				              HelpMessage = "The path to the registry key where the value should be set.  Will be created if it doesn't exist." ) ]
				[ string ]
				$Path,

				[ Parameter ( Mandatory ) ]
				[ string ]
			# The name of the value being set.
				$Name
			)

			if ( -not (Test-Path -Path $Path -PathType Container ) ) {
				return $false
			}

			$properties = Get-ItemProperty -Path $Path
			if ( -not $properties ) {
				return $false
			}

			$member = Get-Member -InputObject $properties -Name $Name
			if ( $member ) {
				return $true
			} else {
				return $false
			}

		}

		function Check-Network {
			$NetworkTimeout = $internetWaitTime
			$ComputerName = 'www.google.co.uk'
			$CheckEvery = 10

			log-write -logstring "Checking network connection to $ComputerName" -fore yellow -notification 2

			## Start the timer
			$timer = [ Diagnostics.Stopwatch ]::StartNew()
			if ( $NetStatus ) { Clear-Variable $NetStatus } # Make sure we are running clean

			## Keep in the loop while the $ComputerName is not pingable
			while ( -not ($NetStatus ) ) {
				$NetStatus = (Test-Connection -ComputerName $ComputerName -Quiet -Count 1 )
				Write-Verbose -Message "Waiting for [$( $ComputerName )] to become connectable ..."
				## If the timer has waited greater than or equal to the timeout, throw an exception exiting the loop
				if ( $timer.Elapsed.TotalSeconds -ge $NetworkTimeout ) {
					log-write -logstring "Connection down exceeded $NetworkTimeout, Restarting script" -fore red -notification 1
					call-Self
				}
				## Stop the loop every $CheckEvery seconds
				if ( -not ($NetStatus ) ) {
					log-write -logstring "Connection down: $($timer.Elapsed.ToString( "hh\:mm\:ss" ) )" -fore red -notification 1
					Start-Sleep -Seconds $CheckEvery
				} elseif (($timer.Elapsed ).seconds -gt 2) {
					log-write -logstring "Connection up: Check time taken $($timer.Elapsed.ToString( "hh\:mm\:ss" ) )" -fore red -notification 2
				}
			}

			## When finished, stop the timer
			$timer.Stop()
			Start-Sleep -Seconds 1
		}

		function check-room-temps {
			$CheckEvery = 10
			$flag = 'True'
			if ( $script:TempWatch -eq 'True' ) {
				if ( test-path -path $sensorDataFile ) {
					$validTime = $null
					log-write -logstring "Checking Room Temp is below $TEMPerMaxTemp c" -fore yellow -notification 2 -linefeed
					get-room-temps
					if ( $script:validSensorTime -eq 'True' ) {
						log-write -logstring "Valid sensor reading within $TEMPerValidMinutes minutes found`t $( $script:lastRoomTemp.Time )" -fore yellow -notification 5
						$validTime = 'True'
					} else {
						log-write -logstring "Invalid Reading, Too much time drift $script:timeDrift minutes, Is your sensor OK ?" -fore red -notification 1
						$validTime = 'False'
					}

					$lt = ($script:lastRoomTemp.OuterTemp )
					$lti = ($script:lastRoomTemp.Time )

					$timer = [ Diagnostics.Stopwatch ]::StartNew()
					if ( $script:validSensorTime -eq 'True' ) {
						if ( $lt -gt $TEMPerMaxTemp ) {
							log-write -logstring "Room temp $lt c, max temp is set at $TEMPerMaxTemp c last reading taken $lti" -fore yellow -notification 1

						} else {
							log-write -logstring "Room temp ok $lt c" -fore green -notification 1
						}

						start-sleep -s $infoMessageTime
						while ( ($script:lastRoomTemp.OuterTemp ) -gt $TEMPerMaxTemp ) {
							if  (($TEMPerValidMinutes - $script:timeDrift) -eq 0) {break}
							Clear-Host
							Write-Host "`n`n`nToo Hot, Waiting for temp drop, Current $lt, Max $TEMPerMaxTemp " -fore Red
							write-host "`nTime before last reading timeouts and script continues is $( $TEMPerValidMinutes - $script:timeDrift ) Minutes" -fore yellow

							if (( $killStakOnMaxTemp -eq 'True' ) -and ($flag -eq 'True')) {
								log-write -logstring "Room temp $lt is past set max $TEMPerMaxTemp killStakOnMaxTemp is enabled so killing stak and disabling GPU's until temp drops" -fore red -notification 1
								kill-Process -STAKexe ($STAKexe )
								reset-VideoCard -stop
								$flag = 'False' # Disable the cards once
							} elseif ($flag -eq 'True') {
								log-write -logstring "Room temp @ $lt c but stop STAK disabled so exiting wait loop to allow script to monitor hashrate" -fore red -notification 1
								break
							}
							write-host "`nSleeping for $CheckEvery Seconds" -fore green
							start-sleep -s $CheckEvery
							get-room-temps
						}
					}

					## When finished, stop the timer
					$timer.Stop()
					if ( $timer.Elapsed.TotalSeconds -gt 60 ) {
						log-write -logstring "Time in cool down loop $( $timer.Elapsed.TotalMinutes ) minutes" -fore Yellow -notification 2
					}
					write-verbose "Exiting Temp Check Loop"

				} else {
					clear-host
					log-write -logstring "TempWatch = True but file $sensorDataFile is not found or unreadable" -fore red -notification 1 -linefeed
					log-write -logstring "Disabling TempWatch, will continue executing in 15 seconds, please correct or disable " -fore red -notification 1
					$script:TempWatch = 'False'
					Start-Sleep -Seconds 15
				}

			}
		}



		function reset-VideoCard {
			##### Reset Video Card(s) #####

			param ([ switch ]$Force, [switch]$stop
			)
			log-Write -logstring 'Resetting Video Card(s)...' -fore White -notification 1
			$allCards = Get-PnpDevice|
			            Where-Object { ($_.friendlyname -in $supported_cards ) -and ($_.Status -NotLike 'Unknown' ) }
			$erroredCards = Get-PnpDevice|
			                Where-Object { ($_.friendlyname -in $supported_cards ) -and ($_.Status -like 'Error' ) }
			if ( $Force ) {
				$d = $allCards
			} else {
				$d = $erroredCards
			}
			$vCTR = 0
			if ( ( $CardResetEnabled -eq 'True' ) -and (-not ($stop ) ) ) {
				foreach ( $dev in $d ) {
					$vCTR = $vCTR + 1
					log-Write -logstring "Disabling $dev" -fore Red -notification 5
					$disableTimer = [ Diagnostics.Stopwatch ]::StartNew()
					$null = Disable-PnpDevice -DeviceId $dev.DeviceID -ErrorAction Ignore -Confirm:$false
					$disableTimer.Stop()
					log-Write -logstring "Disabled $vCTR`t $dev`t time taken $( $disableTimer.Elapsed.TotalSeconds )" -fore yellow -notification 5
					if ( $( $disableTimer.Elapsed.TotalSeconds ) -gt $maxDeviceResetTime ) {
						log-Write -logstring "Device took longer than maxDeviceResetTime to disable" -fore red -notification 0
						Reboot-If-Enabled
					}
					Start-Sleep -Seconds $devwait

					log-Write -logstring "Enabling $dev" -fore Blue -notification 5
					$enableTimer = [ Diagnostics.Stopwatch ]::StartNew()
					$null = Enable-PnpDevice -DeviceId $dev.DeviceID -ErrorAction Ignore -Confirm:$false
					$enableTimer.Stop()
					log-Write -logstring "Enabled $vCTR`t $dev`t time taken $( $enableTimer.Elapsed.TotalSeconds )" -fore yellow -notification 5
					Start-Sleep -Seconds $devwait
				}
				log-Write -logstring "$vCTR Video Card(s) Reset" -fore yellow -notification 1
			} elseif (-not ($stop ) ) {
				log-Write -logstring 'Card reset bypassed' -fore red -notification 0
			}

			if ( ( $CardResetEnabled -eq 'True' ) -and ($stop ) ) {
				log-Write -logstring "Card stop called" -fore Red -notification 1
				foreach ( $dev in $d ) {
					$vCTR = $vCTR + 1
					log-Write -logstring "Disabling $dev" -fore Red -notification 5
					$disableTimer = [ Diagnostics.Stopwatch ]::StartNew()
					$null = Disable-PnpDevice -DeviceId $dev.DeviceID -ErrorAction Ignore -Confirm:$false
					$disableTimer.Stop()
					log-Write -logstring "Disabled $vCTR`t $dev`t time taken $( $disableTimer.Elapsed.TotalSeconds )" -fore yellow -notification 5
					if ( $( $disableTimer.Elapsed.TotalSeconds ) -gt $maxDeviceResetTime ) {
						log-Write -logstring "Device took longer than maxDeviceResetTime to disable" -fore red -notification 0
						Reboot-If-Enabled
					}
					Start-Sleep -Seconds $devwait
				}
			}
		}

		Function Pause-Then-Exit {
			log-Write -logstring 'Pause for user and exit called' -fore Red -notification 0
			Pause
			EXIT
		}

		function call-Self {
			$running = $false
			break
		}

		Function Pause {

			param
			([ string ]
			 $Message = 'Press any key to continue . . . '
			)
			If ( $psISE ) {
				# The "ReadKey" functionality is not supported in Windows PowerShell ISE.

				$Shell = New-Object -ComObject 'WScript.Shell'
				$null = $Shell.Popup( 'Click OK to continue.', 0, 'Script Paused', 0 )
				Return
			}

			Write-Host -NoNewline $Message

			$Ignore = 16, # Shift (left or right)
			17, # Ctrl (left or right)
			18, # Alt (left or right)
			20, # Caps lock
			91, # Windows key (left)
			92, # Windows key (right)
			93, # Menu key
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

			While ( $KeyInfo.VirtualKeyCode -Eq $Null -Or $Ignore -Contains $KeyInfo.VirtualKeyCode ) {
				$KeyInfo = $Host.UI.RawUI.ReadKey( 'NoEcho, IncludeKeyDown' )
			}

		}

		Function refreshSTAK {
			Try {
				$data = $null
				$total = $null
				$data = @{ }
				$total = @{ }
				Write-Verbose -Message 'Querying STAK...this can take a minute.'
				$rawdata = (Invoke-WebRequest -UseBasicParsing -Uri $script:Url -TimeoutSec 60 ) -replace '\\', '\\'
				$flag = 'True'
			}
			Catch {
				Clear-Host
				log-Write -logstring 'Restarting in 10 seconds - Lost connectivity to STAK' -fore red -notification 1
				$script:currHash = 0
				Start-Sleep -Seconds 10
				call-Self


			}
			If ( $flag -eq 'False' ) {
				Break
			}

			$data = $rawdata | ConvertFrom-Json

			# Hashrate Per Thread
			$rawthread = ($data.hashrate ).threads
			$threads = @($rawthread | ForEach-Object { $_[ 0 ] })
			$script:threadArray = $threads

			# Total Hash
			$rawtotal = ($data.hashrate ).total
			$total = $rawtotal | ForEach-Object { $_ }
			$script:currHash = $total[ 0 ]
			# Current difficulty
			$rawdiff = ($data.results ).diff_current
			$currDiff = $rawdiff | ForEach-Object { $_ }
			$script:currDiff = $currDiff[ 0 ]
			# Good shares processed
			$rawSharesGood = ($data.results ).shares_good
			$SharesGood = $rawSharesGood | ForEach-Object { $_ }
			$script:GoodShares = $SharesGood[ 0 ]
			# Total shares processed
			$rawSharesTotal = ($data.results ).shares_total
			$SharesTotal = $rawSharesTotal | ForEach-Object { $_ }
			$script:TotalShares = $SharesTotal[ 0 ]
			# Shares processed time
			$rawSharesTime = ($data.results ).avg_time
			$SharesTime = $rawSharesTime | ForEach-Object { $_ }
			$script:TimeShares = $SharesTime[ 0 ]
			# Share good poercentage
			if ( $script:TotalShares -gt 0 ) {
				$script:sharepercent = [ math ]::Round( (( $script:GoodShares / $script:TotalShares ) * 100 ), 3 )
			}
			# Current Pool
			$script:ConnectedPool = ($data.connection ).pool
			# Pool connected uptime
			$rawTimeUp = ($data.connection ).uptime
			$rawUpTime = $rawTimeUp | ForEach-Object { $_ }
			$script:UpTime = $rawUpTime[ 0 ]

			$script:roomtemp = @{ }
			get-room-temps

		}

		function debug-Check {
			param ([ switch ]$on
			)
			$preferenceHolder = $VerbosePreference

			if ( $on ) {
				$script:VerbosePreference = 'Continue'
			} else {
				$VerbosePreference = $script:VerbosePreferenceDefault
			}
		}

		function get-room-temps {
			if ( $sensorDataFile ) {
				write-verbose "get-room-temps: Sensorfile defined $sensorDataFile"
				if ( test-path -path $sensorDataFile ) {
					$script:sensorData = 'True'
					write-verbose "get-room-temps: Sensorfile exists $sensorDataFile"
					$script:lastRoomTemp = (get-content -path $sensorDataFile ) -replace ('â|„|ƒ' ) |
					                       out-string |
					                       ConvertFrom-Csv |
					                       Select-Object -Last 1
					write-verbose "get-room-temps: Last Time $( $script:lastRoomTemp.Time )"
					write-verbose "get-room-temps: Last Temp $( $script:lastRoomTemp.OuterTemp )"

					$script:timeDrift = [int] (new-timespan -Start ([DateTime] $script:lastRoomTemp.Time ) -End (Get-Date ) ).TotalMinutes

					if ( $TEMPerValidMinutes -gt $script:timeDrift ) {
						write-verbose "Valid Time found $( $script:lastRoomTemp.Time )"
						$script:validSensorTime = 'True'
					} else {
						write-verbose "Invalid Reading, Too much time drift $script:timeDrift "
						$script:validSensorTime = 'False'
						$script:lastRoomTemp = $null
						write-verbose "get-room-temps: Time Drift in minutes $script:timeDrift"
					}

				}
			}
		}


		##################################
		Function refresh-Screen {
			$tmRunTime = get-RunTime -sec ($runTime )
			$tpUpTime = get-RunTime -sec ($script:UpTime )
			$displayOutput = "
          ===========================================================
          Starting Hash Rate:           $script:maxhash H/s
          Restart Hash Rate:            $script:rTarget H/s
          Current Hash Rate:            $script:currHash H/s
          Minimum Hash Rate:            $script:minhashrate H/s
          Monitoring Uptime:            $tmRunTime
          ===========================================================
          Pool:                         $script:ConnectedPool
          Uptime:                       $tpUpTime
          Difficulty:                   $script:currDiff
          Total Shares:                 $script:TotalShares
          Good Shares:                  $script:GoodShares
          Good Share Percent:           $script:sharepercent
          Share Time:                   $script:TimeShares
        ===========================================================

"

			Clear-Host

			if (( $script:validSensorTime -eq 'True' ) -and ($script:lastRoomTemp) ) {
				$displayOutput += "Last Temp Taken"
				$displayOutput += $script:lastRoomTemp | Out-String
			}

			Write-Host -fore Green $displayOutput
			if ( $script:coins ) {
				show-Coin-Info
			}

		}

		Function Run-Tools {
			param ([ Parameter ( Mandatory ) ]
			       $app
			)
			foreach ( $item in $app ) {
				$prog = ($item -split '\s', 2 )
				$e = $ScriptDir + "\" + $prog[ 0 ]
				if ( Test-Path -Path $e ) {
					log-Write -logstring "Starting $item" -fore green -notification 2
					If ( $prog[ 1 ] ) {
						$null = Start-Process -FilePath $e -ArgumentList $prog[ 1 ]
					} Else {
						$null = Start-Process -FilePath $e
					}
					Start-Sleep -Seconds 1
				} Else {
					Write-Host -fore Red "$e NOT found. This is not fatal. Continuing..."
				}
			}
		}

		function start-Mining {
			#####  Start STAK  #####
			$timeStamp = "{0:yyyy-MM-dd_HH:mm}" -f (Get-Date )

			$STAK = "$ScriptDir\$script:STAKfolder\$script:STAKexe"
			If ( Test-Path ($STAK ) ) {
				log-Write -logstring 'Starting STAK' -fore Yellow -notification 2
				If ( $STAKcmdline ) {
					Write-Host "$STAK $STAKcmdline $ScriptDir\$script:STAKfolder"
					Start-Process -FilePath $STAK -ArgumentList $STAKcmdline -WorkingDirectory $ScriptDir\$script:STAKfolder -WindowStyle Minimized
				} Else {
					Write-Host "$STAK $STAKcmdline $ScriptDir\$script:STAKfolder"
					Start-Process -FilePath $STAK -WorkingDirectory $ScriptDir\$script:STAKfolder -WindowStyle Minimized
				}
			} Else {
				log-write -logstring "$script:STAKexe NOT FOUND.. EXITING" -fore Red -notification 0
				Write-Host -fore Red `n`n!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
				Write-Host -fore Red "         $script:STAKexe NOT found. "
				Write-Host -fore Red "   Can't do much without the miner now can you!"
				Write-Host -fore Red '          Now exploding... buh bye!'
				Write-Host -fore Red !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
				Pause-Then-Exit
			}
			Write-Host -fore green "Giving $script:STAKexe 10 seconds to fall over before continuing"
			start-Sleep -Seconds 10
			$prog = ($script:STAKexe -split '\.', 2 )
			$prog = $prog[ 0 ]
			$stakPROC = Get-Process -Name $prog -ErrorAction SilentlyContinue
			if ( -not ($stakPROC ) ) {
				write-host "$prog"
				log-Write -logstring 'stak exited abnormally, Run manually and check output' -fore red -notification 0
				Pause-Then-Exit
			}
		}

		function set-STAKVars {
			log-Write -logstring 'Setting Env Variables for STAK' -fore 0 -notification 2

			[ Environment ]::SetEnvironmentVariable( 'GPU_FORCE_64BIT_PTR', '1', 'User' )
			[ Environment ]::SetEnvironmentVariable( 'GPU_MAX_HEAP_SIZE', '99', 'User' )
			[ Environment ]::SetEnvironmentVariable( 'GPU_MAX_ALLOC_PERCENT', '99', 'User' )
			[ Environment ]::SetEnvironmentVariable( 'GPU_SINGLE_ALLOC_PERCENT', '99', 'User' )

			log-Write -logstring 'Env Variables for STAK have been set' -fore 0 -notification 2
		}

		function get-RunTime {

			param
			([ Parameter ( Mandatory ) ]
			 $sec
			)
			$myTimeSpan = (new-timespan -seconds $sec )
			If ( $sec -ge 3600 -And $sec -lt 86400 ) {
				$script:runHours = $myTimeSpan.Hours
				$script:runMinutes = $myTimeSpan.Minutes
				Return "$script:runHours Hours $script:runMinutes Min"
			} ElseIf ($sec -ge 86400) {
				$script:runDays = $myTimeSpan.Days
				$script:runHours = $myTimeSpan.Hours
				$script:runMinutes = $myTimeSpan.Minutes
				Return "$script:runDays Days $script:runHours Hours $script:runMinutes Min"
			} Elseif ($sec -ge 60 -And $sec -lt 3600) {
				$script:runMinutes = $myTimeSpan.Minutes
				Return "$script:runMinutes Min"
			} Elseif ($sec -lt 60) {
				Return 'Less than 1 minute'
			}
		}

		function Test-IsAdmin () {
			############################## BEGIN ELEVATION #######################################
			# If you can't Elevate you're going to have a bad time...
			# Elevation code written by: Jonathan Bennett
			# License: Not specified
			# https://www.autoitscript.com/forum/topic/174609-powershell-script-to-self-elevate/
			#
			# Test if admin

			# Get the current ID and its security principal
			$windowsID = [ Security.Principal.WindowsIdentity ]::GetCurrent()
			$windowsPrincipal = new-object -TypeName System.Security.Principal.WindowsPrincipal -ArgumentList ($windowsID )

			# Get the Admin role security principal
			$adminRole = [ Security.Principal.WindowsBuiltInRole ]::Administrator

			# Are we an admin role?
			if ( $windowsPrincipal.IsInRole( $adminRole ) ) {
				$true
			} else {
				$false
			}
		}

		function Get-UNCFromPath {
			Param ([ Parameter ( Position = 0, Mandatory, ValueFromPipeline ) ]
			       [ String ]
			       $Path
			)

			if ( $Path.Contains( [ io.path ]::VolumeSeparatorChar ) ) {
				$psdrive = Get-PSDrive -Name $Path.Substring( 0, 1 ) -PSProvider 'FileSystem'

				# Is it a mapped drive?
				if ( $psdrive.DisplayRoot ) {
					$Path = $Path.Replace( $psdrive.Name + [ io.path ]::VolumeSeparatorChar, $psdrive.DisplayRoot )
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
			$Buffer = $Console.BufferSize
			$ConSize = $Console.WindowSize

			# If the Buffer is wider than the new console setting, first reduce the buffer, then do the resize

			try {
				if ( $ConSize.Width ) {
					If ( $Buffer.Width -gt $Width -or $Buffer.Height -gt $Height ) {
						If ( $Buffer.Width -gt $Width ) {
							$ConSize.Width = $Width
						}
						If ( $Buffer.Height -gt $Height ) {
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
					try {
						[ console ]::CursorVisible = $false
					}
					catch {
						Write-Host "Should only see this message in an ide"
					}

				}
			}
			# NOTE: When you use a SPECIFIC catch block, exceptions thrown by -ErrorAction Stop MAY LACK
			# some InvocationInfo details such as ScriptLineNumber.
			# REMEDY: If that affects you, remove the SPECIFIC exception type [System.Management.Automation.PropertyNotFoundException] in the code below
			# and use ONE generic catch block instead. Such a catch block then handles ALL error types, so you would need to
			# add the logic to handle different error types differently by yourself.
			catch [ Management.Automation.PropertyNotFoundException ] {
				# get error record
				[Management.Automation.ErrorRecord] $e = $_

				# retrieve information about runtime error
				$info = [PSCustomObject] @{
					Exception = $e.Exception.Message
					Reason = $e.CategoryInfo.Reason
					Target = $e.CategoryInfo.TargetName
					Script = $e.InvocationInfo.ScriptName
					Line = $e.InvocationInfo.ScriptLineNumber
					Column = $e.InvocationInfo.OffsetInLine
				}

				# output information. Post-process collected info, and log info (optional)
				$info
			}


		}

		function disable_crossfire {
			$videocards = Get-ChildItem -Path 'hklm:\SYSTEM\ControlSet001\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}' -ErrorAction Ignore |
			              Select-Object -ExpandProperty Name
			$registrychanges = 0
			Foreach ( $videocard in $videocards ) {
				$cardnumber = ''
				$cardnumber = ($videocard -split '{4d36e968-e325-11ce-bfc1-08002be10318}' )[ 1 ]
				$cardpath = ''
				$cardpath = Test-RegistryKeyValue -Path "hklm:\SYSTEM\ControlSet001\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}$cardnumber" -Name 'EnableUlps'
				$videocardName = ''
				$videocardnamepath = Test-RegistryKeyValue -Path "hklm:\SYSTEM\ControlSet001\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\$cardnumber" -Name 'DriverDesc'
				if ( $videocardnamepath -eq 'True' ) {
					$videocardName = Get-ItemPropertyValue -Name DriverDesc -Path ("hklm:\SYSTEM\ControlSet001\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\$cardnumber" ) -ErrorAction Ignore
				}

				if ( $cardpath -eq 'True' -And $videocardName -like 'Radeon Vega Frontier Edition' ) {
					Set-ItemProperty -Path "hklm:\SYSTEM\ControlSet001\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}$cardnumber" -Name EnableUlps -Value 0

					Set-ItemProperty -Path "hklm:\SYSTEM\ControlSet001\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}$cardnumber" -Name EnableCrossFireAutoLink -Value 0
					$registrychanges++
					Write-Host "$videocardName Registry settings applied, crossfire is disabled"
				}
			}
		}

		function Supported-Cards-OK {
			$d = $null
			$d = Get-PnpDevice|
			     Where-Object { ($_.friendlyname -in $supported_cards ) -and ($_.Status -like 'Error' ) }
			If ( $d ) {
				return $false
			} else {
				return $true
			}
		}

		Function test-cards {
			$boardCount, $null = (clinfo.exe  | sls  "Board Name" -ErrorAction SilentlyContinue |
			                      sls -n "n/a" ).count
			if ( $boardCount -ge 1 ) {
				$boardActual = $boardCount - 1
				log-write -logstring "Device count $boardActual" -fore red -notification 1
				$deviceinfodebug = (clinfo.exe | sls  "Board Name" ) -replace 'Board Name:'
				if ( $deviceinfodebug ) {
					log-write -logstring "Suppoorted Devices $deviceinfodebug"  -fore red -notification 3
				}
				if ( $boardActual -lt $installedCards ) {
					log-write -logstring "Cards seen $boardActual is less than installedCards setting of $installedCards" -fore red -notification 1
					reset-VideoCard -force
				}
				$boardCount, $null = (clinfo.exe  | sls  "Board Name" -ErrorAction SilentlyContinue |
				                      sls -n "n/a" ).count
				$boardActual = $boardCount - 1
				if ( $boardActual -gt $installedCards ) {
					$installedCards = $boardActual
				}
			}
			$test = (Supported-Cards-OK )
			if ( $test -eq "True" ) {
				Write-Host 'Driver Status is OK' -fore Green
			} else {
				if ( $ResetCardOnStartup -ne 'True' ) {
					log-Write -logstring 'Driver in error state, Resetting' -fore red -notification 1
					reset-VideoCard
				}
				log-write -logstring 'Re-Checking Driver for error status in 5 seconds' -fore Blue -notification 4
				Start-Sleep -Seconds 5
				write-host 'Gpu OK ' (Supported-Cards-OK )
				if ( Supported-Cards-OK ) {
					Write-Host "GPU's OK" -fore Green
				} else {
					log-Write -logstring "Driver in error state" -fore red -notification 1
					reboot-If-Enabled
				} # End of device test
			} # End of driver error
		}

		Function Reboot-If-Enabled {
			Log-Write -logstring "Checking if reboot enabled: $rebootEnabled" -fore Red -notification 4
			if ( $rebootEnabled -eq 'True' ) {
				log-Write -logstring "Reboot enabled, Resetting in $rebootTimeout seconds " -fore red -notification 0
				Start-Sleep -Seconds $rebootTimeout
				Restart-Computer -Force
				EXIT
			} else {
				log-Write -logstring 'Reboot not enabled' -fore red -notification 0
				Pause-Then-Exit
			}
		}

		Function quickcheckSTAK {
			param ([ Parameter ( Mandatory ) ]$script:Url
			)
			log-Write -logstring 'Quick Check Stak' -fore yellow -notification 4

			$flag = 'False'
			$web = New-Object -TypeName System.Net.WebClient

			$ts = New-TimeSpan -Seconds $runningSTAKtimeout
			$elapsedTimer = [ Diagnostics.Stopwatch ]::StartNew()
			DO {
				Try {
					$null = $web.DownloadString( $script:Url )
					$flag = 'True'
					$script:STAKisup = $true
				}
				Catch {
					$timeDiff = (($elapsedTimer.Elapsed - $ts ).Seconds ) -replace '-'
					Write-Host -fore Green -NoNewline $timeDiff
					$script:STAKisup = $false
				}
			} While (($elapsedTimer.Elapsed -lt $ts ) -And ($flag -eq 'False' ))
			$elapsedTimer.Stop()
			check-room-temps
			If ( -not ($script:STAKisup ) ) {
				Clear-Host
				# Check if profit switching is enabled and generate pools.txt if it is using pools.json
				if ( $profitSwitching -eq 'True' ) {

					log-write -logstring "Profit switching enabled" -fore green -notification 1
					if ( read-Pools-File ) {
						check-Profit-Stats $script:PoolsList.Keys $script:minhashrate
						get-coin-specific-parameters
						write-xmrstak-Pools-File
						write-host "Starting mining using the following pools.txt"
						get-content -path "$STAKfolder\$poolsdottext"
						log-write -logstring "Continuing in $sleeptime seconds" -fore yellow -notification 4
						start-sleep -s $sleeptime
					} else {
						log-Write -logstring "Issue reading  $STAKfolder\$poolsfile" -fore red -notification 1
						log-write -logstring "Error messages `n $( $Error[ 0 ].InvocationInfo.line )"
					}
				}

				kill-Process -STAKexe ($STAKexe )
				if ( $ResetCardOnStartup -eq 'True' ) {
					reset-VideoCard -force
				}
				test-cards
				disable_crossfire
				& "$env:windir\system32\ipconfig.exe" /FlushDNS
				If ( ! (Supported-Cards-OK ) ) {
					reset-VideoCard
				}
				If ( $script:vidToolArray ) {
					Run-Tools -app ($script:vidToolArray )
				}
				set-STAKVars # Set  environment variables
				start-Mining # Start mining software
			}
		}

		Function chk-STAK {
			param ([ Parameter ( Mandatory ) ]
			       $script:Url
			)

			$flag = 'False'
			$web = New-Object -TypeName System.Net.WebClient
			$ts = New-TimeSpan -Seconds $timeout
			$elapsedTimer = [ Diagnostics.Stopwatch ]::StartNew()
			DO {
				Try {
					$null = $web.DownloadString( $script:Url )
					$flag = 'True'
				}
				Catch {
					Clear-Host
					$timeDiff = (($elapsedTimer.Elapsed - $ts ).Seconds ) -replace '-'
					Write-host -fore Red "STAK not ready... Waiting up to $timeDiff seconds."
					Write-host -fore Red 'Press CTRL-C to EXIT NOW'
					Start-Sleep -Seconds 1
				}
			} While (($elapsedTimer.Elapsed -lt $ts ) -And ($flag -eq 'False' ))
			$elapsedTimer.Stop()

			If ( $flag -eq 'True' ) {
				Clear-Host
				log-Write -logstring 'STAK API responding' -fore Green -notification 5
			} ElseIf ($flag -eq 'False') {
				Clear-Host
				log-Write -logstring '!! Timed out waiting for STAK HTTP daemon to start !!' -fore red -notification 1

				# Check for hanging stak on startup, This can also be caused by setting STAKmin too low
				if ( check-Process -exe $script:STAKexe ) {
					$startattempt += 1
					log-Write -fore red -logstring "Abnormal Stak process seems to have hung on strartup or your minhashrate $script:minhashrate is too low, attempt $startattempt" -notification 1
					if ( ($startattempt -ge $STAKMaxStartAttempts ) -and ($STAKMaxStartAttempts -gt 0 ) ) {
						log-write -logstring "Restarting computer in 10 seconds"  -fore red -notification 0
						start-sleep -s 10
						reboot-If-Enabled
					} elseif (($startattempt -ge $STAKMaxStartAttempts ) -and ($STAKMaxStartAttempts -eq 0 ) ) {
						log-write -logstring "Reboot disabled, stopping here, please investigate STAK startup" -fore red -notification 0
						Pause-Then-Exit
					} else {
						call-self
					}
				}
			} Else {
				Clear-Host
				log-Write -logstring 'Unknown failure starting STAK (Daemon failed to start?)' -fore red -notification 0
				Pause-Then-Exit
			}
		}

		function check-Process {
			param ([ Parameter ( Mandatory ) ]
			       $exe
			)
			try {
				$prog = ($exe -split '\.', 2 )
				$prog = $prog[ 0 ]

				# get process
				$app = Get-Process -Name $prog -ErrorAction SilentlyContinue
				if ( $app ) {
					return $true
				} else {
					return $false
				}
			}
			catch {
				return $false
			}

		}

		function dead-Thread-Check {
			param ([ Parameter ( Mandatory ) ]
			       $threads
			)
			log-write -logstring "Dead thread check" -fore yellow -notification 1
			$nullThreadsReturned = 0

			foreach ( $thread in $threads ) {

				if ( $thread[ 0 ] ) {
					write-host "Thread ok $( $thread[ 0 ] )"
				} else {
					write-host "null thread"
					$nullThreadsReturned += 1
				}


			}

			log-write -logstring "$nullThreadsReturned dead threads found" -fore yellow -notification 1
			Start-Sleep -s 3
			if ( $nullThreadsReturned -gt 0 ) {
				log-write -logstring "Dead threads detected, Most likely going to need a reboot " -fore red -notification 1
				kill-Process -STAKexe ($STAKexe )
				$script:STAKisup = $false
				if ( $ResetCardOnStartup -ne 'True' ) {
					reset-VideoCard -force
				}
				$script:currHash = 0
				call-Self
			}
		}


		function starting-Hash {
			log-Write -logstring 'Waiting for hash rate to stabilize' -fore Yellow -notification 5
			$ts = New-TimeSpan -Seconds $STAKstable
			$elapsedTimer = [ Diagnostics.Stopwatch ]::StartNew()
			$flag = $false
			# Wait $STAKstable seconds for hash rate to stabilize
			while ( ($elapsedTimer.Elapsed -lt $ts ) -And (-Not ($flag ) ) ) {
				$currTestHash = 0
				$data = $null
				$total = $null
				$data = @{ }
				$total = @{ }
				$rawdata = (Invoke-WebRequest -UseBasicParsing -Uri $script:Url -TimeoutSec 60 ) -replace '\\', '\\'
				If ( $rawdata ) {
					$data = $rawdata | ConvertFrom-Json
					$rawtotal = ($data.hashrate ).total
					$total = $rawtotal | ForEach-Object { $_ }

					$currTestHash = $total[ 0 ]
					If ( ! $startTestHash ) {
						$startTestHash = $currTestHash
					}
					If ( $script:STAKisup ) {
						log-Write -logstring 'STAK was already running, Skipping wait time' -fore Green -notification 5
						dead-Thread-Check ($data.hashrate ).threads
						$flag = $true
						BREAK
					}

					Clear-Host
					If ( $currTestHash ) {
						Write-host -fore Green "Current Hash Rate: $currTestHash H/s"
					}
					$timeDiff = (($elapsedTimer.Elapsed - $ts ).Seconds ) -replace '-'
					Write-host -fore Green "Waiting $timeDiff seconds for hashrate to stabilize."
					Write-host -fore Red 'Press CTRL-C to EXIT NOW'

					$script:currHash = $currTestHash
					if ( $currTestHash -gt 0 ) {
						# Hashrate Per Thread
						$rawthread = ($data.hashrate ).threads
						$threads = @($rawthread | ForEach-Object { $_[ 0 ] })
						$script:threadArray = $threads
						grafana
						If ( ($currTestHash -lt $script:minhashrate ) -and ($timeDiff -gt $minlowratecheck ) ) {
							lowratecheck $minlowratecheck
							$flag = $true
						}
					}
				}
				Start-Sleep -Seconds 1
			}
			$elapsedTimer.Stop()

			If ( ! $currTestHash ) {
				dead-Thread-Check ($data.hashrate ).threads
				Clear-Host
				log-Write -logstring 'Could not get hashrate... restarting in 3 seconds' -fore Red -notification 1
				log-Write -logstring "API data from failure `n$rawdata" -fore red -notification 4
				Start-Sleep -Seconds 3
				call-Self
			} ElseIf ( $currTestHash -gt $startTestHash) {
				$script:maxhash = $currTestHash
			} Else {
				$script:maxhash = $startTestHash
			}

			$script:currHash = $currTestHash
			$script:rTarget = ($script:maxhash - $script:hdiff )
			log-Write -logstring "Starting Hashrate: $script:maxhash H/s	Drop Target Hashrate: $script:rTarget H/s" -fore Green -notification 1
		}

		function current-Hash {
			If ( $script:rTarget -gt $script:minhashrate ) {
				$script:minhashrate = $script:rTarget
			}
			clear-host
			log-Write -logstring 'Hash monitoring has begun.' -fore Green -notification 3
			$timer = 0
			$runTime = 0
			$flag = 'False'
			DO {
				refreshSTAK
				refresh-Screen
				grafana
				Start-Sleep -Seconds $sleeptime
				$timer = ($timer + $sleeptime )
				$runTime = ($timer )
			} while ($script:currHash -gt $script:minhashrate )

			If ( $script:currHash -lt $script:minhashrate ) {
				lowratecheck $script:minhashrate
				refreshSTAK
			}

			If ( ($flag -eq 'True' ) -And ($script:currHash -lt $script:minhashrate ) ) {
				$tFormat = get-RunTime -sec ($runTime )
				log-Write -logstring "Restarting in 10 seconds after $tFormat - Hash rate dropped from $script:maxhash H/s to $script:currHash H/s" -fore Red -notification 1
				Start-Sleep -Seconds 10
				$script:STAKisup = $false
				kill-Process -STAKexe ($STAKexe )
				call-self
			}
		}

		function lowratecheck {
			Param ([ Parameter ( Mandatory ) ]
			       [ int ]
			       $ratetocheck
			)
			$tFormat = get-RunTime -sec ($runTime )
			log-Write -logstring "Low hash rate check triggered: after $tFormat - Hash rate dropped from $script:maxhash H/s to $script:currHash H/s" -fore Red -notification 1
			$flag = 'False'
			Check-Network # Check we have internet access
			refreshSTAK   # Re-check STAK, Check-Network can be infinate

			$ts = New-TimeSpan -Seconds 60
			$deadTimer = [ Diagnostics.Stopwatch ]::StartNew()
			# Check if we are connected  to a pool
			while ( ($script:UpTime -eq 0 ) -And ($deadTimer.Elapsed -lt $ts ) ) {
				write-host -fore red "Conection died, Pausing for up to $ts Seconds for it too recover $( ($deadTimer.Elapsed ).Seconds )"
				Start-Sleep -Seconds 1
				refreshSTAK
				$flag = 'True'
			}
			$deadTimer.stop()

			if ( $script:currHash -gt $ratetocheck ) {
				$flag = 'True'
			}
			$ts = New-TimeSpan -Seconds $script:retrytimer
			$elapsedTimer = [ Diagnostics.Stopwatch ]::StartNew()

			# Hashdrop testing loop
			While ( (($elapsedTimer.Elapsed -lt $ts ).Seconds ) -and ($flag -eq 'False' ) ) {
				clear-host
				refreshSTAK
				$countdown = (($elapsedTimer.Elapsed -le $ts ).Seconds ) -replace '-'
				Write-host -fore Red "Hash rate $script:currHash H/s less than set minimum $ratetocheck H/s"
				Write-host -fore Red "Waiting for $countdown seconds for it to recover"

				if ( $script:currHash -gt $ratetocheck ) {
					Write-Host -fore Green 'Above min hash rate'
					$flag = 'True'
					break
				} else {
					Write-Host -fore Red 'Below min hash rate'
				}
				Start-Sleep -Seconds 1 # Itteration wait time
			}

			if ( $flag -eq 'False' ) {
				log-Write -logstring "Restarting Script after $tFormat - Hash rate $script:currHash H/s less than set minimum $ratetocheck H/s" -fore red -notification 1
				kill-Process -STAKexe ($STAKexe )
				$script:STAKisup = $false
				if ( (Supported-Cards-OK ) -and ($ResetCardOnStartup -ne 'True' ) ) {
					reset-VideoCard -force # Low rate triggered but driver ok, lets force a card reset and exit
				}
				$script:currHash = 0
				call-Self
			} elseif ((($deadTimer.Elapsed ).seconds -gt 1 ) -and ($flag = 'True' )) {
				log-Write -logstring "Temporary connection issue > 1s, Recovery time $( ($deadTimer.Elapsed ).seconds )"  -fore Red -notification 1
			}
			refreshSTAK
		}

		function kill-Process {
			param ([ Parameter ( Mandatory ) ]
			       $STAKexe
			)
			try {
				$prog = ($STAKexe -split '\.', 2 )
				$prog = $prog[ 0 ]
				$failureMessage = "
            Failed to kill the process $prog
            If we don't stop here STAK would be invoked over and over until the PC crashed.
          That would be very bad...."

				# get STAK process
				$stakPROC = Get-Process -Name $prog -ErrorAction SilentlyContinue
				if ( $stakPROC ) {
					# try gracefully first
					$null = $stakPROC.CloseMainWindow()
					# kill after five seconds
					Start-Sleep -Seconds 5
					if ( ! $stakPROC.HasExited ) {
						$null = $stakPROC | Stop-Process -Force
					}
					if ( ! $stakPROC.HasExited ) {
						Write-host -fore Red $failureMessage
						log-Write -logstring "Failed to kill $prog" -fore 0 -notification 1
						Pause-Then-Exit
					} Else {
						log-Write -logstring 'STAK closed successfully' -fore Green -notification 5
					}
				} Else {
					log-Write -logstring "$prog process was not found" -Fore Green -notification 5
				}
			}
			Catch {
				Write-host -fore Red failureMessage
				log-Write -logstring "Failed to kill $prog" -fore 0 -notification 0
				Pause-Then-Exit
			}
		}

		Function grafana {
			if ( $grafanaEnabled -eq 'True' ) {
				$Metrics = @{
					Total_Hash_Rate = [int] $script:currHash
					Difficulty = [int] $script:currDiff
					Total_Shares = [int] $script:TotalShares
					Good_Shares = [int] $script:GoodShares
					Average_time = [int] $script:TimeShares
				}

				# Add in per thread hashrate
				if ( $script:threadArray[ 0 ] ) {
					$script:threadArray | ForEach-Object -Begin { $seq = 0 } -Process {
						$key = "Thread_$seq"
						$Metrics.add( $key, $script:threadArray[ $seq ] )
						$seq++
					}
				}


				if (( $script:lastRoomTemp ) -and ($script:validSensorTime -eq 'True')) {
					$t = [Decimal] ($script:lastRoomTemp ).OuterTemp
					$Metrics.add( "Room_Temp_float", $t )

				}


				if ( $script:enableNanopool -eq 'True' ) {
					if ( ($runTime - $script:nanopoolLastUpdate ) -ge 1 ) {

						try {
							nanopoolvars
							if ( $script:provider -ne 'nanopool' ) {
								$pool, $diff = $script:ConnectedPool.split( ':' )
								log-write -logstring "Not using Nanopool, you are using $pool, disabling stats" -fore red -notification 1
								$script:enableNanopool = 'False'
							} else {
								[Decimal] $script:balance = [ math ]::Round( (Get-Nanopool-Metric -coin $script:coin -op balance -wallet $script:adr ).data,
								                                             4 )
								[Decimal] $script:btcprice = [Double] ((Get-Nanopool-Metric -coin $script:coin -op prices ).data.'price_btc' )
								[int] $script:avghash1hr = (Get-Nanopool-Metric -coin $script:coin -op avghashrateworker -wallet $script:adr -worker $script:worker ).data.'h1'

								$profitData = (Get-Nanopool-Metric -coin $script:coin -op approximated_earnings -hashrate $script:currHash ).data
								[decimal] $script:coins = [ math ]::Round( $profitData.$coinStats.'coins', 8 )
								[decimal] $script:dollars = [ math ]::Round( $profitData.$coinStats.'dollars', 4 )

								$Metrics.add( 'balance', $script:balance )
								$Metrics.add( 'btcprice', $script:btcprice )
								$Metrics.add( "estCoin$coinStats", $script:coins )
								$Metrics.add( "estDollar$coinStats", $script:dollars )
								$Metrics.add( 'avghash1hr', $script:avghash1hr )
								$script:nanopoolLastUpdate = $runTime
							}
						}
						catch {
							log-write -logstring "Nanoppol api stats issue" -fore yellow -notification 2
						}
					}
				}
				Write-InfluxUDP -Measure Hashrate -Tags @{ Server = $env:COMPUTERNAME } -Metrics $Metrics -IP $grafanaUtpIP -Port $grafanaUtpPort # -Verbose
			}
		}

		Function show-Coin-Info {
			$t = $host.ui.RawUI.ForegroundColor
			$host.ui.RawUI.ForegroundColor = "Green"
			$coininfo = New-Object PSObject
			$coininfo  | Add-Member -NotePropertyName 'Balance' -NotePropertyValue $script:balance
			$coininfo  | Add-Member -NotePropertyName 'H/R' -NotePropertyValue $script:avghash1hr
			$coininfo  | Add-Member -NotePropertyName 'BTC' -NotePropertyValue   $script:btcprice
			$coininfo  | Add-Member -NotePropertyName $( $script:coin ) -NotePropertyValue  $script:coins
			$coininfo  |
			Add-Member -NotePropertyName "BTC per $coinStats" -NotePropertyValue $( $script:coins * $script:btcprice )
			$coininfo  | Add-Member -NotePropertyName Dollars  -NotePropertyValue $script:dollars
			$coininfo | Format-Table
			$host.ui.RawUI.ForegroundColor = $t
		}

		Function check-Influx {
			if ( $grafanaEnabled -eq 'True' ) {
				$error.clear()
				Import-Module "Influx" -ErrorAction SilentlyContinue
				if ( $error ) {
					$error.Clear()
					Clear-Host
					Write-Host "`n`n`n`n`n`n`n`n`n`n"
					log-Write -logstring "You need Influx modules to write to Grafana, " -fore Red -Linefeed -notification 1
					log-Write -logstring "https://github.com/markwragg/PowerShell-Influx" -Fore Yellow -Linefeed -notification 2
					$a = new-object -comobject wscript.shell
					$intAnswer = $a.popup( "Do you want to install these now ?", 10,
					                       "Install modules from https://github.com/markwragg/PowerShell-Influx",
					                       4 + 32 )
					If ( $intAnswer -eq 6 ) {
						log-write -logstring "Installing https://github.com/markwragg/PowerShell-Influx" -fore yellow -notification 1
						Install-Module Influx -Scope CurrentUser -ErrorAction Inquire
					}
				}

				$error.Clear()
				Import-Module "Influx" -ErrorAction SilentlyContinue
				if ( $error ) {
					$grafanaEnabled = 'False'
					log-Write -logstring "Disabling Grafana for now" -fore Green  -Linefeed -notification 1
				}
			}
		}

		Function nanopoolvars {
			IF ( Test-Path -Path ("$STAKfolder\\pools.txt" ) ) {
				Write-Verbose  'reading pools.txt'

				$pool = (($script:ConnectedPool ) -Split ':' )[ 0 ]
				$rawPoolData = Get-Content -Path ("$STAKfolder\\pools.txt" ) |
				               Where-Object { ($_.Contains( $pool ) ) } |
				               Out-String

				$rawWalletData = Get-Content -Path ("$STAKfolder\\pools.txt" ) |
				                 Where-Object { ($_.Contains( 'wallet_address' ) ) } |
				                 Out-String

				if ( $rawPoolData ) {
					$pooldata = $rawPoolData -replace '\{' -replace '\},' -replace '"' -replace ':', '=' -replace ',', "`n" |
					            ConvertFrom-StringData
					$walletdata = $rawWalletData -replace '\{' -replace '\},' -replace '"' -replace ':', '=' -replace ',', "`n" |
					              ConvertFrom-StringData

					$wallet = $walletdata.'wallet_address'

					try {
						if ( $wallet -match '/' ) {
							$miner, $null = $wallet.split( '/' )
						}
						if ( $miner -match '.' ) {
							$script:adr, $script:worker = $miner.split( '.' )
						} else {
							$script:adr = $miner
						}
						$coinzone, $script:provider, $null = $pool.split( '.' )
						$script:coin, $null = $coinzone.split( '-' )
					}
					catch {
						log-write -logstring "Error reading pools file, disabling nanopool" -fore red -notification 1
						$script:enableNanopool = 'False'
					}
				} else {
					log-Write -logstring "Connected pool not found in pools.txt" -fore red -notification 2
				}
			}
		}

		function read-Pools-File {
			if ( test-path -path $poolsfile ) {
				try {
					$poolData = (Get-Content -Path .\pools.json ) -notmatch "^#|^/"| Out-String
					(ConvertFrom-Json $poolData ).psobject.properties |
					ForEach-Object { $script:PoolsList[ $_.Name ] = $_.Value }
					return $true
				}
				catch { return $false }
			} else {
				return $false
			}
		}


		Function check-Profit-Stats {
			Param ([ Parameter ( Position = 0, Mandatory, ValueFromPipeline ) ]$coins,
			       [ Parameter ( Position = 1, Mandatory, ValueFromPipeline ) ][ int ]$hr
			)
			$statsURL = "https://minecryptonight.net/api/rewards?hr=$hr&limit=0"
			$uridata = $null
			$path = "$ScriptDir\profit.json"
			$data = @{ }
			if ( $coins ) { $supportedCoins = $coins.ToUpper() }
			$bestcoins = [Ordered] @{ }

			function get-stats {
				try {
					$uridata = Invoke-WebRequest -UseBasicParsing -Uri $statsURL -TimeoutSec 60
					$uridata | Set-Content -Path $path
				}
				catch {
					log-write -logstring "Issue updating profit stats, Using last set" -for red -notification 2
				}
			}

			# Refresh stats file
			if ( ! (Test-Path -path $path ) ) {
				get-stats
			} else {
				$test = Get-Item $path |
				        Where-Object{ $_.LastWriteTime -lt (Get-Date ).AddSeconds( - $proftStatRefreshTime ) }
				if ( $test ) {
					get-stats
					write-host "Profit stats refreshed from https://minecryptonight.net/api/rewards "
				}
			}

			#Read from profit.json
			$rawdata = (Get-Content -RAW -Path $path | Out-String | ConvertFrom-Json )

			#Add each coin to an ordered list, Storing each coin's name as the value so item 0 is always best coin
			foreach ( $coin in $rawdata.rewards ) {
				#write-host $coin.ticker_symbol $coin.reward_24h.btc
				if ( ($coin.ticker_symbol ) |Where-Object ({ $_ -in $supportedCoins } ) ) {
					$script:pools.Add( [Decimal] $coin.reward_24h.btc, $coin.ticker_symbol )
				} else {
					$bestcoins.Add( [Decimal] $coin.reward_24h.btc, $coin.ticker_symbol )
				}
			}

			#Check our pools
			if ( $script:pools ) {

				log-write -logstring "Coins checked,  We are going to mine $( $script:pools[ 0 ] )" -fore green -notification 1
				log-write -logstring "Possible pools earnings per day from stats with a min hashrate of $hr H/s" -fore yellow -notification 2
				log-write -logstring  ($script:pools | out-string ) -fore yellow -notification 3
				$bestcoin = ($bestcoins.GetEnumerator() | Select-Object -First 1 ).Name
				$ourcoin = ($script:pools.GetEnumerator() | Select-Object -First 1 ).Name
				$profitLoss = $bestcoin - $ourcoin

				# Export coin to mine to script
				$script:coinToMine = $script:pools[ 0 ]

				log-write -logstring "You would have earned $profitLoss more BTC Per day Mining $( $bestcoins[ 0 ] )" -fore yellow -notification 1
			} else {
				log-write -logstring "No compatable entries found in $ScriptDir\pools.txt"
			}
		}


		function get-coin-specific-parameters {
			$poolfile = @{ }
			$settings = @{ }
			$rawobj = $script:PoolsList.($script:coinToMine )
			$rawobj.psobject.properties | ForEach-Object { $poolfile[ $_.Name ] = $_.Value }
			if ( $rawobj.settings ) {
				$rawobj.settings.psobject.properties | ForEach-Object { $settings[ $_.Name ] = $_.Value }

				log-write -logstring "Reading settings from proft $poolsfile  " -fore white -notification 2 -linefeed
				if ( $settings.hdiff ) {
					$script:hdiff = ($settings ).hdiff
				}

				if ( $settings.tools ) {
					$script:vidToolArray = $settings.tools
				}

				if ( $settings.minhashrate ) {
					$script:minhashrate = ($settings ).minhashrate
				}

				$out = "Settings found"
				$out += "`n hdiff = $script:hdiff"
				foreach ( $item in $script:vidToolArray ) {
					$out += "`n $item"
				}
				$out += "`n minhashrate = $script:minhashrate"
				$out += "`n $( $script:amd )"
				$out += "`n $( $script:nvidia )"
				$out += "`n $( $script:cpu )"
				log-write -logstring $out -fore white -notification 3 -Linefeed

				if ( $settings.amd ) {
					$defaultamd = 'default_amd.txt'
					$script:amd = ($settings ).amd
					if ( test-path -path "$ScriptDir\$script:STAKfolder\$script:amd" ) {
						try {

							copy-item ("$ScriptDir\$script:STAKfolder\$script:amd" ) -destination ("$ScriptDir\$script:STAKfolder\amd.txt" )

						}
						catch {
							log-write -logstring "Error copying $( "$ScriptDir\$script:STAKfolder\$script:amd" )" -fore red -notification 3
						}
					} else {
						log-write -logstring "File not found  $( "$ScriptDir\$script:STAKfolder\$script:amd" ) loading defaults "-fore Red -notification 3 -linefeed

						if ( test-path -path "$ScriptDir\$script:STAKfolder\$defaultamd" ) {
							$null = (copy-item ("$ScriptDir\$script:STAKfolder\$defaultamd" ) -destination ("$ScriptDir\$script:STAKfolder\amd.txt" ) -force )
							log-write -logstring "Copying $( "$ScriptDir\$script:STAKfolder\$defaultamd" )" -fore white -notification 3
						} else {
							log-write -logstring "Can't read $( "$ScriptDir\$script:STAKfolder\$defaultamd" ) you need this file to fall back too, can be empty"  -fore red -notification 3
							Pause-Then-Exit
						}
					}
				}

				if ( $settings.nvidia ) {
					$defaultnv = 'default_nvidia.txt'
					$script:nvidia = ($settings ).nvidia
					if ( test-path -path "$ScriptDir\$script:STAKfolder\$script:nvidia" ) {
						try {
							copy-item ("$ScriptDir\$script:STAKfolder\$script:nvidia" ) -destination ("$ScriptDir\$script:STAKfolder\nvidia.txt" )
							log-write -logstring "Copying $( "$ScriptDir\$script:STAKfolder\$script:nvidia" )"  -fore white -notification 3

						}
						catch {
							log-write -logstring "Error copying $( "$ScriptDir\$script:STAKfolder\$script:nvidia" )"  -fore red -notification 3
						}
					} else {
						log-write -logstring "File not found  $( "$ScriptDir\$script:STAKfolder\$script:nvidia" ) loading defaults "-fore Red -notification 3 -linefeed
						if ( test-path -path "$ScriptDir\$script:STAKfolder\$defaultnv" ) {
							$null = (copy-item ("$ScriptDir\$script:STAKfolder\$defaultnv" ) -destination ("$ScriptDir\$script:STAKfolder\nvidia.txt" ) -force )
							log-write -logstring "Copying $( "$ScriptDir\$script:STAKfolder\$defaultnv" )" -fore white -notification 3
						} else {
							log-write -logstring "Can't read $( "$ScriptDir\$script:STAKfolder\$defaultnv" ) you need this file to fall back too, can be empty"  -fore red -notification 3
							Pause-Then-Exit
						}
					}
				}

				if ( $settings.cpu ) {
					$defaultcpu = 'default_cpu.txt'
					$script:cpu = ($settings ).cpu
					if ( test-path -path "$ScriptDir\$script:STAKfolder\$script:cpu" ) {
						try {
							$null = (copy-item ("$ScriptDir\$script:STAKfolder\$script:cpu" ) -destination ("$ScriptDir\$script:STAKfolder\cpu.txt" ) )
							log-write -logstring "Copying $( "$ScriptDir\$script:STAKfolder\$script:cpu" )" -fore white -notification 3
						}
						catch {
							log-write -logstring "Error copying $( "$ScriptDir\$script:STAKfolder\$script:cpu" )" -fore red -notification 3
						}
					} else {
						log-write -logstring "File not found  $( "$ScriptDir\$script:STAKfolder\$script:cpu" ) loading defaults  " -fore Red -notification 3 -linefeed
						if ( test-path -path "$ScriptDir\$script:STAKfolder\$defaultcpu" ) {
							$null = (copy-item ("$ScriptDir\$script:STAKfolder\$defaultcpu" ) -destination ("$ScriptDir\$script:STAKfolder\cpu.txt" ) -force )
							log-write -logstring "Copying  $( "$ScriptDir\$script:STAKfolder" )\$defaultcpu " -fore white -notification 3
						} else {
							log-write -logstring "Can't read $( "$ScriptDir\$script:STAKfolder\$defaultcpu" ) you need this file to fall back too, can be empty"  -fore red -notification 3
							Pause-Then-Exit
						}
					}
				}
			}
		}

		function write-xmrstak-Pools-File {


			function Select-Address {
				param
				([ Parameter ( Mandatory = $true, ValueFromPipeline = $true, HelpMessage = "Data to process" ) ]
				 $InputObject
				)
				process
				{
					$pool[ $InputObject.Name ] = $InputObject.Value
				}
			}

			$script:poolsdottextContent = '"pool_list" : [' + "`n"

			$poolfile = @{ }
			$pool = @{ }
			$rawobj = $script:PoolsList.($script:coinToMine )
			$rawobj.psobject.properties | ForEach-Object { $poolfile[ $_.Name ] = $_.Value }
			$rawobj.address.psobject.properties | Select-Address

			$footer = '],
            "currency" : "' + $( $poolfile.algorithm ) + '",
            '
			function write-entry {
				Param ([ Parameter ( Position = 1, Mandatory, ValueFromPipeline ) ][ string ]$key,
				       [ Parameter ( Position = 2, Mandatory, ValueFromPipeline ) ][ string ]$value
				)
				$r = $poolfile.Clone()
				$r.add( "pool_address", $key )
				$r.add( "pool_weight", [int] $value )
				$r.Remove( "address" )
				$r.Remove( "algorithm" )
				$r.Remove( "settings" )
				$r.Remove( "amd_txt" )
				$r.Remove( "nvidia_txt" )
				$r.Remove( "cpu_txt" )
				$l = $r | ConvertTo-Json
				$script:poolsdottextContent += ($l + ",`n" )
			}


			if ( test-path -path "$ScriptDir\$STAKfolder" ) {
				try {
					log-write -logstring "Writing $STAKfolder\$poolsdottext" -fore green -notification 1
					foreach ( $p in ($pool ).keys ) {
						write-entry $p $pool.$p
					}
					$script:poolsdottextContent += $footer
					$script:poolsdottextContent | Set-Content -Path "$ScriptDir\$STAKfolder\$poolsdottext"

				}
				catch {
					log-write -logstring "Error Writing $STAKfolder\$poolsdottext" -fore red -notification 1
					Pause-Then-Exit

				}
			} else {
				return $false
			}

		}





		##### END FUNCTIONS #####


		##### MAIN - or The Fun Starts Here #####
		do {
			debug-Check # disable verbose mode
			$ProgressPreference = 'SilentlyContinue' # Disable web request progress bar
			#$ErrorActionPreference='Continue' # Keep going

			# Relaunch if not admin
			Invoke-RequireAdmin -MyInvocation $script:MyInvocation

			# Display key settings
			if ( $initalRun ) {
				log-Write -logstring "Starting the Hash Monitor Script... $ver "-fore White -linefeed  -notification 1
				$initalRun = $false
			} Else {
				log-Write -logstring '== Loop Started ==' -fore Green -notification 5
			}

			#Display critical settings Variable
			$settingsToScreen = "`n"
			$settingsToScreen += "Displaying Startup Settings `n"

			# Add settings params to output
			if ( $rebootEnabled )       { $settingsToScreen += "Reboot enabled:             $rebootEnabled `n" }
			if ( $CardResetEnabled )    { $settingsToScreen += "Reset Cards enabled:        $CardResetEnabled `n" }
			if ( $ResetCardOnStartup )  { $settingsToScreen += "Reset Cards on startup:     $ResetCardOnStartup `n" }
			if ( $profitSwitching )     { $settingsToScreen += "Profit Switching enabled:   $profitSwitching `n" }
			if ( $script:TempWatch )    { $settingsToScreen += "TempWatch enabled:          $script:TempWatch `n" }
			if ( $killStakOnMaxTemp )   { $settingsToScreen += "killStakOnMaxTemp:          $killStakOnMaxTemp `n" }
			if ( $TEMPerMaxTemp )       { $settingsToScreen += "TEMPerMaxTemp:              $TEMPerMaxTemp `n" }
			Log-Write -logstring $settingsToScreen -fore 'White' -notification 2 -linefeed # Display settings

			write-host "You have $sleeptime seconds before we start next run" -fore Green
			Start-Sleep -Seconds $sleeptime

			Resize-Console
			check-Influx                    # check for modules and cancel if needed
			Check-Network                   # Check you can open google.com on port 80, Prove your network is working

			quickcheckSTAK  ($script:Url )  # check and start stak if not running
			chk-STAK  ($script:Url )        # Wait for STAK to return a hash rate
			starting-Hash                  # Get the starting hash rate
			current-Hash                   # Gather the current hash rate every $sleeptime seconds until it drops beneath the threshold

			log-Write -logstring 'Repeat Loop' -fore red -notification 4

			# End of mining loop
		} while ($running -eq $true) # Keep running until restart triggered, triggered in call-Self

		# Setup for next run
		log-write -logstring "Restart triggered`n`n" -fore Red -notification 1
		$running = $true

	} while ( $active -eq $true ) # Used to exit script from anywhwere in code, ignored in fatal driver error

} # End of Run-Miner Function

# Runtime Variables
$active = $true
$running = $true

# Kick off mining
$initalRun = $true
Run-Miner

$ProgressPreference = 'Continue'