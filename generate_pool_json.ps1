

function dev-test {
	$PoolsList = @{
		xmr = @{
			address = @{
				"xmr-eu1.nanopool.org:14433" = 1
			}
			wallet_address = "49QA139gTEVMDV9LrTbx3qGKKEoYJucCtT4t5oUHHWfPBQbKc4MdktXfKSeT1ggoYVQhVsZcPAMphRS8vu8oxTf769NDTMu.$($env:COMPUTERNAME)/pass@heynes.biz"
			rig_id = "$($env:COMPUTERNAME)"
			pool_password = "pass@heynes.biz"
			use_nicehash = $false
			use_tls = $true
			tls_fingerprint =''
			algorithm = 'monero7'
			settings = @{
				hdiff = 500
				tools = ('OverdriveNTool.exe -consoleonly -r1 -p1XMR','OverdriveNTool.exe -consoleonly -r1 -p1XMR')
				minhashrate = 2200
			}
		}
		etn = @{
			address = @{
				"xmr-eu1.nanopool.org:14433" = 1
			}
			wallet_address = "etnk7Rc6TSLeKeSw5rB7D4ZyaztbffkKh5dpk4PoQ5vaVaHrK4XP5xfQgCiMdwL3uLgCjPL9VFu4Q8vi6yParLv65rXHVq1XvB.$($env:COMPUTERNAME)/pass@heynes.biz"
			rig_id = "$($env:COMPUTERNAME)"
			pool_password = "pass@heynes.biz"
			use_nicehash = $false
			use_tls = $true
			tls_fingerprint =''
			algorithm = 'monero7'
			settings = @{
				hdiff = 500
				tools = ('OverdriveNTool.exe -consoleonly -r1 -p1XMR','OverdriveNTool.exe -consoleonly -r1 -p1XMR')
				minhashrate = 4000
			}
		}
		sumo = @{
			address = @{
				"pool.sumokoin.hashvault.pro:5555" = 50
				"london01.sumokoin.hashvault.pro:5555" = 50
			}
			wallet_address = "Sumoo13hApaeJmf5eRyukdfVVN13wZcDtEvPqzgzNJ2PDuVY5Z9Mrg2WkZQt5vbHwt8k2xV96aYJSVww33c9R6KNMMUjwcHVjSv"
			rig_id = "$($env:COMPUTERNAME)"
			pool_password = "pass@heynes.biz"
			use_nicehash = $false
			use_tls = $true
			tls_fingerprint =''
			algorithm = 'sumokin'
		}
		msr = @{
			address = @{
				"pool.masaricoin.com:5555" = 1
			}
			wallet_address = "5t5mEm254JNJ9HqRjY9vCiTE8aZALHX3v8TqhyQ3TTF9VHKZQXkRYjPDweT9kK4rJw7dDLtZXGjav2z9y24vXCdRc4mgijA99QZ94AZzaz"
			rig_id = "$($env:COMPUTERNAME)"
			pool_password = "pass@heynes.biz"
			use_nicehash = $false
			use_tls = $false
			tls_fingerprint =''
			algorithm = 'cryptonight_masari'
			settings = @{
				hdiff = 600
				tools = ('OverdriveNTool.exe -consoleonly -r1 -p1XMR', 'OverdriveNTool.exe -consoleonly -r1 -p1XMR')
				minhashrate = 4000
				amd = 'msr_amd.txt'
				nvidia = 'msr_nvidia.txt'
				cpu = 'msrcpu.txt'
			}

		}
	}


	#$PoolsList | ConvertTo-Json -Depth 4
	$poolsfile = 'pools.json'

	$PoolsList | ConvertTo-Json -Depth 6 | Set-Content $poolsfile
	get-Content $poolsfile
}

dev-test