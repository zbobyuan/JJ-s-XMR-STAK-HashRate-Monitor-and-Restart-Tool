function dev-test {
	$PoolsList = @{
		xmr = @{
			address = @{
				"xmr-eu1.nanopool.org:14433" = 1
			}
			wallet_address = "49QA139gTEVMDV9LrTbx3qGKKEoYJucCtT4t5oUHHWfPBQbKc4MdktXfKSeT1ggoYVQhVsZcPAMphRS8vu8oxTf769NDTMu.$( $env:COMPUTERNAME )/pass@heynes.biz"
			rig_id = "$( $env:COMPUTERNAME )"
			pool_password = "pass@heynes.biz"
			use_nicehash = $false
			use_tls = $true
			tls_fingerprint = ''
			algorithm = 'monero7'
			settings = @{
				hdiff = 500
				minhashrate = 2200
			}
		}
		msr = @{
			address = @{
				"pool.masaricoin.com:5555" = 1
			}
			wallet_address = "5t5mEm254JNJ9HqRjY9vCiTE8aZALHX3v8TqhyQ3TTF9VHKZQXkRYjPDweT9kK4rJw7dDLtZXGjav2z9y24vXCdRc4mgijA99QZ94AZzaz+100000"
			rig_id = "$( $env:COMPUTERNAME )"
			pool_password = "pass@heynes.biz"
			use_nicehash = $false
			use_tls = $false
			tls_fingerprint = ''
			algorithm = 'cryptonight_masari'
			settings = @{
				hdiff = 600
				minhashrate = 3800
				amd = 'msr_amd.txt'
				nvidia = 'msr_nvidia.txt'
				cpu = 'msrcpu.txt'
			}

		}
		trtl = @{
			enabled = 'False'
			address = @{
				"trtl.pool.mine2gether.com:6665" = 10
			}
			wallet_address = "TRTLv2rhdaNPxiYYAAWcvpRqonkKgmvxa7BcSi8vErdm49h5osRfSWvKjqhYgG64XDJ89o9AdM1FkDmt8n3etpNT383f7BBQ4Xt"
			rig_id = "$( $env:COMPUTERNAME )"
			pool_password = "$( $env:COMPUTERNAME )"
			use_nicehash = $false
			use_tls = $false
			tls_fingerprint = ''
			algorithm = 'turtlecoin'
			settings = @{
				hdiff = 600
				minhashrate = 3800
				amd = 'msr_amd.txt'
				nvidia = 'msr_nvidia.txt'
				cpu = 'msrcpu.txt'
			}

		}
		loki = @{
			address = @{
				"loki.ingest.cryptoknight.cc:7732" = 10
			}
			wallet_address = "LK8CGQ17G9R3ys3Xf33wCeViD2B95jgdpjAhcRsjuheJ784dumXn7g3RPAzedWpFq364jJKYL9dkQ8mY66sZG9BiD26SpDVGQGQQsaPZpq"
			rig_id = "$( $env:COMPUTERNAME )"
			pool_password = "$( $env:COMPUTERNAME )"
			use_nicehash = $false
			use_tls = $false
			tls_fingerprint = ''
			algorithm = 'cryptonight_heavy'
			settings = @{
				hdiff = 300
				minhashrate = 2000
				amd = 'heavy.txt'
				nvidia = 'msr_nvidia.txt'
				cpu = 'msrcpu.txt'
			}

		}
		tube = @{
			address = @{
				" mining.bit.tube:1777" = 10
			}
			wallet_address = "bi1b95WYJRES7oBrvRo2eQV53ExLzFAzjKVM4wp9H9B6irCR6UuQxHf183XsJwemdoQm5PUHhQVwS67Hf5yUE7qg4Swbe5w7KE393ez1baaX7"
			rig_id = "$( $env:COMPUTERNAME )"
			pool_password = "$( $env:COMPUTERNAME )"
			use_nicehash = $false
			use_tls = $false
			tls_fingerprint = ''
			algorithm = 'cryptonight_bittube2'
			settings = @{
				hdiff = 300
				minhashrate = 2000
				amd = 'heavy.txt'
				nvidia = 'msr_nvidia.txt'
				cpu = 'msrcpu.txt'
			}

		}
		XHV = @{
			address = @{
				"haven.ingest.cryptoknight.cc:5832" = 10
			}
			wallet_address = "hvi1aCqoAZF19J8pijvqnrUkeAeP8Rvr4XyfDMGJcarhbL15KgYKM1hN7kiHMu3fer5k8JJ8YRLKCahDKFgLFgJMYAfnF4hGrpK3byEeSWP1f"
			rig_id = "$( $env:COMPUTERNAME )"
			pool_password = "$( $env:COMPUTERNAME )"
			use_nicehash = $false
			use_tls = $false
			tls_fingerprint = ''
			algorithm = 'cryptonight_haven'
			settings = @{
				hdiff = 300
				minhashrate = 2000
				amd = 'heavy.txt'
				nvidia = 'msr_nvidia.txt'
				cpu = 'msrcpu.txt'
			}

		}

	}

	$poolsfile = 'pools.json'

	$PoolsList | ConvertTo-Json -Depth 6 | Set-Content $poolsfile
	get-Content $poolsfile
}

dev-test