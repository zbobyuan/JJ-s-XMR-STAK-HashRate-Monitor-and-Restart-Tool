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
	


	Copyright 2017, TheJerichoJones
