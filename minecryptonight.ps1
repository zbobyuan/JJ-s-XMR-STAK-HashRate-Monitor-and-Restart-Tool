Push-Location -Path $PSScriptRoot

Function log-Write {
	param ([Parameter(Mandatory, HelpMessage = 'String')][string]$logstring,
	       [Parameter(Mandatory, HelpMessage = 'Provide colour to display to screen')][string]$fore, [switch] $linefeed, [int] $notification

	)
	$timeStamp = (get-Date -format r)
	if ($fore -ne '0') {
		Write-Host -Fore $fore "$logstring"
	}
	}


$script:pools = [ Ordered ]@{ }

$proftStatRefreshTime = 60


Function check-Profit-Stats {
	Param ([ Parameter ( Position = 0, Mandatory, ValueFromPipeline ) ]$coins
	)
	$statsURL = "https://minecryptonight.net/api/rewards?hr=10000&limit=0"
	$bestURL = $data = $null
	$uridata = $null
	$path = "$PSScriptRoot\profit.json"
	$data = @{ }
	$supportedCoins = $coins.ToUpper()
	$bestcoins = [ Ordered ]@{ }

	function get-stats {
		$uridata = Invoke-WebRequest -UseBasicParsing -Uri $statsURL -TimeoutSec 60
		$uridata | Set-Content -Path $path
	}

	# Refresh stats file every 60 seconds
	if ( ! (Test-Path -path $path ) ) {
		get-stats
	}
	else {
		$test = Get-Item $path | Where{ $_.LastWriteTime -lt (Get-Date ).AddSeconds( - $proftStatRefreshTime ) }
		if ( $test ) {
			get-stats
			write-host "Profit stats refreshed from https://minecryptonight.net/api/rewards "
		}
	}

	#Read from profit.json
	$rawdata = (Get-Content -RAW -Path $path| Out-String | ConvertFrom-Json )

	#Add each coin to an ordered list, Storing each coin's name as the value so item 0 is always best coin
	foreach ( $coin in $rawdata.rewards ) {
		#write-host $coin.ticker_symbol $coin.reward_24h.btc
		if ( ($coin.ticker_symbol ) |Where-Object ({ $_ -in $supportedCoins } ) ) {
			$script:pools.Add( [ Decimal ]$coin.reward_24h.btc, $coin.ticker_symbol )
		}
		else {
			$bestcoins.Add( [ Decimal ]$coin.reward_24h.btc, $coin.ticker_symbol )
		}
	}

	#Select top coin
	log-write -logstring "We are going to mine $( $script:pools[ 0 ] )" -fore green -notification 1
	$bestcoin = ($bestcoins.GetEnumerator() | Select-Object -First 1 ).Name
	$ourcoin = ($script:pools.GetEnumerator() | Select-Object -First 1 ).Name
	$profitLoss = $bestcoin - $ourcoin

	# Export coin to mine to script
	$script:coinToMine = $script:pools[ 0 ]

	log-write -logstring "You would have earned $profitLoss more Per day Mining $( $bestcoins[ 0 ] )" -fore yellow -notification 2
}

check-Profit-Stats @('etn', 'xmr', 'msr')