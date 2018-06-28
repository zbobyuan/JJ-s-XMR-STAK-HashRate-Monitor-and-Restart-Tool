Push-Location -Path $PSScriptRoot
Function log-Write {
	param ([ Parameter ( Mandatory, HelpMessage = 'String' ) ][ string ]$logstring,
	       [ Parameter ( Mandatory, HelpMessage = 'Provide colour to display to screen' ) ][ string ]$fore, [ switch ] $linefeed, [ int ] $notification
	)
	$timeStamp = (get-Date -format r )
	if ( $fore -ne '0' ) {
		Write-Host -Fore $fore "$logstring"
	}
}


$PoolsList = @{
	xmr = @{
		address = @{
			address = "xmr-eu1.nanopool.org:14433"
			weight = 1
		}
		wallet = "49QA139gTEVMDV9LrTbx3qGKKEoYJucCtT4t5oUHHWfPBQbKc4MdktXfKSeT1ggoYVQhVsZcPAMphRS8vu8oxTf769NDTMu.xmrstackpc/pass@heynes.biz"
		rig_id = "xmrstackpc"
		password = "pass@heynes.biz"
		use_tls = 'true'
		algorithm = 'monero7'
	}
	etn = @{
		address = @{
			address = "xmr-eu1.nanopool.org:14433"
			weight = 1
		}
		wallet = "etnk7Rc6TSLeKeSw5rB7D4ZyaztbffkKh5dpk4PoQ5vaVaHrK4XP5xfQgCiMdwL3uLgCjPL9VFu4Q8vi6yParLv65rXHVq1XvB.xmrstackpc/pass@heynes.biz"
		rig_id = "xmrstackpc"
		password = "pass@heynes.biz"
		use_tls = 'true'
		algorithm = 'monero7'
	}
	sumo = @{
		address = @{
			"pool.sumokoin.hashvault.pro:5555" = 50
			"london01.sumokoin.hashvault.pro:5555" = 50
		}
		wallet = "Sumoo13hApaeJmf5eRyukdfVVN13wZcDtEvPqzgzNJ2PDuVY5Z9Mrg2WkZQt5vbHwt8k2xV96aYJSVww33c9R6KNMMUjwcHVjSv"
		rig_id = "xmrstackpc"
		password = "pass@heynes.biz"
		use_tls = 'true'
		algorithm = 'sumokin'
	}
	msr = @{
		address = @{
			"pool.masaricoin.com:5555" = 1
		}
		wallet = "5mBTDBeXbNT46sX6HhaoGyazJb2Xu8LBqB83iueKPXGKEW4T2zMayxeWzoCjMFqLeHgYpGk9qykcMhbAttqkhjUkJSQE2zM"
		rig_id = "xmrstackpc"
		password = "pass@heynes.biz"
		use_tls = 'true'
		algorithm = 'masari'
	}
}



$poolsfile = 'pools.json'
$PoolsList | ConvertTo-Json -Depth 4 | Set-Content $poolsfile

$script:PoolsList = @{}
$script:pools = [ Ordered ]@{ }
$proftStatRefreshTime = 60
$profitSwitching = 'True'


function read-Pools-File {

	if ( test-path -path $poolsfile ) {
		try {
				$poolData = get-content -RAW  "$PSScriptRoot\$poolsfile"
		(ConvertFrom-Json $poolData ).psobject.properties | Foreach { $script:PoolsList[ $_.Name ] = $_.Value }
		return $true}
		catch {return $false}
	} else {
		return $false
	}
}


Function check-Profit-Stats {
	Param (
		[ Parameter ( Position = 0, Mandatory, ValueFromPipeline ) ]$coins,
		[ Parameter ( Position = 1, Mandatory, ValueFromPipeline ) ][int]$hr
	)
	$statsURL = "https://minecryptonight.net/api/rewards?hr=$hr&limit=0"
	$bestURL = $data = $null
	$uridata = $null
	$path = "$PSScriptRoot\profit.json"
	$data = @{ }
	if ($coins) {$supportedCoins = $coins.ToUpper()}
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

	#Check our pools
	if ( $script:pools ) {

		log-write -logstring "Coins checked,  We are going to mine $( $script:pools[ 0 ] )" -fore green -notification 1
		log-write -logstring "Possible pools earnings per day from stats with a hashrate of $hr H/s" -fore yellow
		write-host ($script:pools | out-string )
		$bestcoin = ($bestcoins.GetEnumerator() | Select-Object -First 1 ).Name
		$ourcoin = ($script:pools.GetEnumerator() | Select-Object -First 1 ).Name
		$profitLoss = $bestcoin - $ourcoin

		# Export coin to mine to script
		$script:coinToMine = $script:pools[ 0 ]

		log-write -logstring "You would have earned $profitLoss more BTC Per day Mining $( $bestcoins[ 0 ] )" -fore yellow -notification 2
	} else {
		log-write -logstring "No compatable entries found in $PSScriptRoot\pools.txt"
	}
}

function write-xmrstak-Pools-File {

	if ( test-path -path $poolsfile ) {
		try {
			$poolData = get-content -RAW  "$PSScriptRoot\$poolsfile"
			(ConvertFrom-Json $poolData ).psobject.properties | Foreach { $script:PoolsList[ $_.Name ] = $_.Value }
			return $true}
		catch {return $false}
	} else {
		return $false
	}
}



# Check if profit switching is enabled and generate pools.txt if it is using pools.json
if ($profitSwitching -eq 'True') {
	log-write -logstring "Profit switching enabled" -fore green -notification 1
	if (read-Pools-File) {
		check-Profit-Stats $script:PoolsList.Keys 7500
	} else {
		log-Write -logstring "Issue reading $PSScriptRoot\pools.txt" -fore red -notification 1
	}
}

