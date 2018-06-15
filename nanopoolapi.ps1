#requires -Version 3.0

#!/usr/bin/env powershell
  $test = 'False'
 # $test = 'True'
  $wallet_address = 'etnk7Rc6TSLeKeSw5rB7D4ZyaztbffkKh5dpk4PoQ5vaVaHrK4XP5xfQgCiMdwL3uLgCjPL9VFu4Q8vi6yParLv65rXHVq1XvB'
  $worker = 'xmrstackpc'
  $adr = $wallet_address
  $coin = 'etn'
  $url = 'https://api.nanopool.org/v1'
  
  
 


  function Get-Nanopool-Metric
  {
      <#
        .Synopsis
        Generic Nanopool Metric cmdlet
        .DESCRIPTION
        Generic Nanopool Metric cmdlet
        Easily get any stat from nanoppol for any coin
        Get-Nanopool-Metric -coin $coin -op prices
        Get-Nanopool-Metric -coin etn -op balance -wallet $adr
        Get-Nanopool-Metric -coin etn -op avghashrateworker -wallet $adr -worker $worker
        .INPUTS
        Inputs to this cmdlet (if any)
        .OUTPUTS
        Output from this cmdlet (if any)
        .NOTES
        General notes
        .COMPONENT
    #>


    [OutputType([int])]
    Param
    (
      # Which coin to check
      [Parameter(Mandatory,HelpMessage='You must specify a coin',ValueFromPipelineByPropertyName)]
      [string]
      $coin,

      # Over how many hours
      #[Parameter(Mandatory=$true)][int]
      [int]
      $Xhrs,
        
      # Operation to be performed
      [string]
      $op,
        
      # Wallet Address Dynamic param
      #[string]
      #$wallet,
        
      # Worker Name Dynamic param
      #[string]
      #$worker,
        
      # Hashrate to use in calculations
      [decimal]
      $hashrate,
        
      # Offset to use
      [int]
      $offset,
        
      # Count
      [int]
      $count
    )

   
    DynamicParam {
      # Create a parameter dictionary
      $paramDictionary = New-Object -TypeName System.Management.Automation.RuntimeDefinedParameterDictionary
      
      # Check if op needs as wallet address    
      if (($op -notin ('approximated_earnings','block_stats','blocks','network_avgblocktime', 'network_lastblocknumber', 'network_timetonextepoch', 'pool_activeminers', 'pool_activeworkers', 'pool_hashrate', 'pool_topminers', 'prices') -and ($op)))
      {
          Write-Verbose -Message ('wallet check {0}' -f $op)
          $walletattribute = New-Object -TypeName System.Management.Automation.ParameterAttribute
          #$walletattribute.Position = 6
          $walletattribute.Mandatory = $true
          $walletattribute.HelpMessage = 'I need a wallet address for this'
 
          #create an attributecollection object for the attribute we just created.
          $attributeCollection = new-object -TypeName System.Collections.ObjectModel.Collection[System.Attribute]
 
          #add our custom attribute
          $attributeCollection.Add($walletattribute)
 
          #add our paramater specifying the attribute collection
          $walletparam = New-Object -TypeName System.Management.Automation.RuntimeDefinedParameter -ArgumentList ('wallet', [string], $attributeCollection)
 
          #expose the name of our parameter
          $paramDictionary.Add('wallet', $walletparam)         
      }
      
      # Check if op needs a worker address    
      if (($op -in ('avghashrateworker','avghashratelimited','avghashrateworkers','hashratechart','history','pool_activeworkers','reportedhashrate','shareratehistory','workers')))
      {
        Write-Verbose -Message ('Worker check {0}' -f $op)
        #create a new ParameterAttribute Object
        $workerattribute = New-Object -TypeName System.Management.Automation.ParameterAttribute
        #$workerattribute.Position = 7
        $workerattribute.Mandatory = $true
        $workerattribute.HelpMessage = 'I need a worker name for this'
 
        #create an attributecollection object for the attribute we just created.
        $attributeCollection = new-object -TypeName System.Collections.ObjectModel.Collection[System.Attribute]
 
        #add our custom attribute
        $attributeCollection.Add($workerattribute)
 
        #add our paramater specifying the attribute collection
        $workerparam = New-Object -TypeName System.Management.Automation.RuntimeDefinedParameter -ArgumentList ('worker', [string], $attributeCollection)
 
        #expose the name of our parameter
        $paramDictionary.Add('worker', $workerparam)


      }

      return $paramDictionary 
    }   
     
    Begin    {
      if ($PSBoundParameters.wallet) { $wallet = $PSBoundParameters.wallet}
      if ($PSBoundParameters.worker) { $worker = $PSBoundParameters.worker}
      #Write-Verbose -Message "Nanopool API for $coin $op $wallet $worker"
      $null = 'True'

      # Select Operation
      $stat = switch ($op) 
      {        
        'accountexist'             {                      ('accountexist/{0}' -f $wallet)                   }
        'approximated_earnings'    {                      ('approximated_earnings/{0}' -f $hashrate)        }
        'avghashrate'              {                      ('avghashrate/{0}' -f $wallet)                    }
        'avghashrateworker'        {                      ('avghashrate/{0}/{1}' -f $wallet, $worker)            }
        'avghashratelimited'       {                      ('avghashratelimited/{0}/{1}/{2}' -f $wallet, $worker, $Xhrs)  }
        'avghashratelimited'       {                      ('avghashratelimited/{0}/{1}' -f $wallet, $Xhrs)          }
        'avghashrateworkers'       {                      ('avghashrateworkers/{0}' -f $wallet)                }
        'balance'                  {                      ('balance/{0}' -f $wallet)                           }
        'balance_hashrate'         {                      ('balance_hashrate/{0}' -f $wallet)                  }
        'balance_unconfirmed'      {                      ('balance_unconfirmed/{0}' -f $wallet)               }
        'block_stats'              {                      ('block_stats/{0}/{1}' -f $offset, $count)             }
        'blocks'                   {                      ('blocks/{0}/{1}' -f $offset, $count)                  }
        'hashrate'                 {                      ('hashrate/{0}' -f $wallet)                       }
        'hashratechart'            {                      ('hashratechart/{0}/{1}' -f $wallet, $worker)          }
        'hashratechart'            {                      ('hashratechart/{0}' -f $wallet)                  }
        'history'                  {                      ('history/{0}' -f $wallet)                        }
        'history'                  {                      ('history/{0}/{1}' -f $wallet, $worker)                }
        'network_avgblocktime'     {                      'network/avgblocktime'                   }
        'network_lastblocknumber'  {                      'network/lastblocknumber'                }
        'network_timetonextepoch'  {                      'network/timetonextepoch'                }
        'payments'                 {                      ('payments/{0}' -f $wallet)                       }
        'paymentsday'              {                      ('paymentsday/{0}' -f $wallet)                    }
        'pool_activeminers'        {                      'pool/activeminers'                      }
        'pool_activeworkers'       {                      'pool/activeworkers'                     }
        'pool_hashrate'            {                      'pool/hashrate'                          }
        'pool_topminers'           {                      'pool/topminers'                         }
        'prices'                   {                      'prices'                                 }
        'reportedhashrate'         {                      ('reportedhashrate/{0}' -f $wallet)               }
        'reportedhashrate'         {                      ('reportedhashrate/{0}/{1}' -f $wallet, $worker)       }
        'reportedhashrates'        {                      ('reportedhashrates/{0}' -f $wallet)              }
        'shareratehistory'         {                      ('shareratehistory/{0}' -f $wallet)               }
        'shareratehistory'         {                      ('shareratehistory/{0}/{1}' -f $wallet, $worker)       }
        'shareratehistory'         {                      ('shareratehistory/{0}/{1}' -f $wallet, $Xhrs)         }
        'user'                     {                      ('user/{0}' -f $wallet)                           }
        'usersettings'             {                      ('usersettings/{0}' -f $wallet)                   }
        'workers'                  {                      ('workers/{0}' -f $wallet)                        }    
        default                    {                      'prices'                        }
      }
      $timeStamp = '{0:yyyy-MM-dd_HH:mm}' -f (Get-Date)
    }

    Process    {
      Try {
        $data = $null
        $null = $null
        $data = @{}
        $rawdata = Invoke-WebRequest -UseBasicParsing -Uri $url/$coin/$stat -TimeoutSec 60
        $null = 'True'
        Write-Verbose -Message ("{0}`t Nanopool API call  `n{1}/{2}/{3} `n{4}" -f $timeStamp, $url, $coin, $stat, $rawdata) #-verbose
      }
      Catch
      {
        
        Write-Verbose -Message ("{0}`t Nanopool issue with API call `n{1}/{2}/{3} `n{4}" -f $timeStamp, $url, $coin, $stat, $rawdata) -Verbose
        $null = 'False'
      }
    }

    End    {
      $data = $rawdata | ConvertFrom-Json
      return $data
    }
  }
  
   if ($test -eq 'True') {
     #  Pull Test Stats
     # Floats
     Get-Nanopool-Metric -coin $coin -op prices
     Get-Nanopool-Metric -coin etn -op balance -wallet $adr
     Get-Nanopool-Metric -coin etn -op avghashrateworker -wallet $adr -worker $worker
   }
