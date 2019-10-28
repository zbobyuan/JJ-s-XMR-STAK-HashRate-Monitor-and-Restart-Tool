***Profit mining specific setup.***

If you enable profit switching you are going to need to follow this guide.

First things first, copy your gpu config file and prefix with __default___ 
``` bash
copy amd.txt default_amd.txt
copy nvidia.txt default_nvidia.txt
copy cpu.txt default_cpu.txt
```

These will be used if you do not specify coin specific configs so make sure they are sensible to fall back too.

They can be empty, If you don't specify them they will use whats there so if you want to specify one then specify all 3 amd, nvidia and cpu even if they are blank

Pools.txt that will be used is displayed to the screen and saved to your logs for review

**_**hdiff**_** , **_minhashrate_** &  **_vidTools_**   use defaults from hashmonitor.ini if not specified

`Example json commenting suppoorted `
 ``` js
 "settings":  {
    "tools":  [
/      __"OverdriveNTool.exe -consoleonly -r1 -p1XMR",__
      "OverdriveNTool.exe -consoleonly -r2 -p2XMR"
    ],
 #   "minhashrate":  2200,
    "hdiff":  300
    },
```  

                            
I have included **_generate_pool_json.ps1_** to generate an example pools.json file which lives in the same folder as the hashmonitor script/executable

You either have the choice to maintain your configs in powershell or json format, If you choose powershell you must run the file after each change to generate the .json file.

The pools.json file can have sections commented out using either `/` or `#` sections go from { to },

The last item in and json section does not have a comma, if you comment the one without the comma you are going to need to delete the comma at the end of the procedeeding line, its pretty easy I just make it sound difficult. See the following links for some help

More info
https://www.w3schools.com/js/js_json_intro.asp

To validate
https://jsonlint.com/

Example pools.json
``` json
{
    "xmr":  {
                "pool_password":  "pass@heynes.biz",
                "algorithm":  "monero7",
                "tls_fingerprint":  "",
                "use_tls":  true,
                "rig_id":  "MARK-PC",
                "address":  {
                                "xmr-eu1.nanopool.org:14433":  1
                            },
                "settings":  {
                                 "tools":  [
                                               "OverdriveNTool.exe -consoleonly -r2 -p2XMR"
                                           ],
                                 "minhashrate":  2200,
                                 "hdiff":  300
                             },
                "use_nicehash":  false,
                "wallet_address":  "49QA139gTEVMDV9LrTbx3qGKKEoYJucCtT4t5oUHHWfPBQbKc4MdktXfKSeT1ggoYVQhVsZcPAMphRS8vu8oxTf769NDTMu.MARK-PC/pass@heynes.biz"
            },
    "msr":  {
                "pool_password":  "pass@heynes.biz",
                "algorithm":  "cryptonight_masari",
                "tls_fingerprint":  "",
                "use_tls":  false,
                "rig_id":  "MARK-PC",
                "address":  {
                                "pool.masaricoin.com:5555":  1
                            },
                "settings":  {
                                 "nvidia":  "msr_nvidia.txt",
                                 "cpu":  "msrcpu.txt",
                                 "hdiff":  500,
                                 "amd":  "msr_amd.txt",
                                 "tools":  [
                                               "OverdriveNTool.exe -consoleonly -r1 -p1XMR"
                                           ],
                                 "minhashrate":  4000
                             },
                "use_nicehash":  false,
                "wallet_address":  "5t5mEm254JNJ9HqRjY9vCiTE8aZALHX3v8TqhyQ3TTF9VHKZQXkRYjPDweT9kK4rJw7dDLtZXGjav2z9y24vXCdRc4mgijA99QZ94AZzaz+80000"
            },
    "sumo":  {
                 "enabled" : "False"
                 "wallet_address":  "Sumoo13hApaeJmf5eRyukdfVVN13wZcDtEvPqzgzNJ2PDuVY5Z9Mrg2WkZQt5vbHwt8k2xV96aYJSVww33c9R6KNMMUjwcHVjSv",
                 "pool_password":  "pass@heynes.biz",
                 "use_nicehash":  false,
                 "algorithm":  "sumokin",
                 "tls_fingerprint":  "",
                 "use_tls":  true,
                 "rig_id":  "MARK-PC",
                 "address":  {
                                 "london01.sumokoin.hashvault.pro:5555":  50,
                                 "pool.sumokoin.hashvault.pro:5555":  50
                             }
             }
}
```

