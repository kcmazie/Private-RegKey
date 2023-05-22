Param (
  [Switch]$Debug = $false,
  [Switch]$Console = $false
)
<#======================================================================================
         File Name : Private-RegKey.ps1
   Original Author : Kenneth C. Mazie  (kcmjr AT kcmjr DOT com)
                   : 
       Description : Sets custom registry keys on all domain PCs.  This version only creates and populates with "-" as a default.
                   : If an existing value is found no changes are made.  It is expected that other processes and/or
                   : scripts will populate the keys with appropriate values.  This just makes sure the key and value
                   : structure is in place.   Creates a simplified email report with results.
                   : 
             Notes : Normal operation is with no command line options.  
                   : Optional argument: -Debug $true (defaults to false) 
                   :                    -DebugTarget name (only applies if in debug)
                   :                    -Console $true (enables local console output)
                   : 
          Warnings : None
                   :   
             Legal : Public Domain. Modify and redistribute freely. No rights reserved.
                   : SCRIPT PROVIDED "AS IS" WITHOUT WARRANTIES OR GUARANTEES OF 
                   : ANY KIND. USE AT YOUR OWN RISK. NO TECHNICAL SUPPORT PROVIDED.
                   : That being said, please report any bugs you find!!
                   :
           Credits : Code snippets and/or ideas came from many sources including but 
                   :   not limited to the following:
                   : 
    Last Update by : Kenneth C. Mazie 
   Version History : v1.00 - 12-06-13 - Original 
    Change History : v1.10 - 02-08-16 - Added "auto logon" key   
                   : v1.20 - 04-13-16 - Added authorized local admins key
                   : v2.00 - 06-27-17 - Complete rewrite using invoke-command instead of .net or WMI.
                   : v2.10 - 01-11-18 - Fixed issue with credentials.
                   : v2.20 - 10-04-18 - Added new keys.  Changed name & added values for PS Gallery.
                   : v3.00 - 10-10-18 - Added a list of keys checked to report.  Complete rewrite of
                   :                    registry pull to speed up domain wide checks.
#                  :
#=======================================================================================#>
<#PSScriptInfo
.VERSION 3.00
.AUTHOR Kenneth C. Mazie (kcmjr AT kcmjr.com)
.DESCRIPTION 
Sets custom registry keys on all domain PCs.  This version only creates and populates with "-" as a default.
If an existing value is found no changes are made.  It is expected that other processes and/or
scripts will populate the keys with appropriate values.  This just makes sure the key and value
structure is in place.  Creates a simplified email report with results.  An option to include updates
is available.
#>

clear-host
$ErrorActionPreference = "SilentlyContinue"

#--[ Functions ]-------------------------------------------------------------------------
Function LoadModules {
        Import-Module ActiveDirectory
}

Function LoadConfig { #--[ Read and load configuration file ]-----------------------------------------
    If (!(Test-Path $Script:ConfigFile)){       #--[ Error out if configuration file doesn't exist ]--
        $Script:EmailBody = "---------------------------------------------`n" 
        $Script:EmailBody += "--[ MISSING CONFIG FILE.  Script aborted. ]--`n" 
        $Script:EmailBody += "---------------------------------------------" 
       SendEmail
        Write-Host $EmailBody -ForegroundColor Red
       break
    }Else{
     [xml]$Script:Configuration = Get-Content $Script:ConfigFile   
     $Script:DebugTarget = $Script:Configuration.Settings.General.DebugTarget
        $Script:RegistryPath = $Script:Configuration.Settings.General.RegistryPath
        $Script:Domain = $Script:Configuration.Settings.General.Domain
        $Script:DebugEmail = $Script:Configuration.Settings.Email.Debug 
        $Script:CompanyName = $Script:Configuration.Settings.Email.CompanyName 
     $Script:eMailTo = $Script:Configuration.Settings.Email.To
     $Script:eMailFrom = $Script:Configuration.Settings.Email.From 
     $Script:eMailHTML = $Script:Configuration.Settings.Email.HTML
     $Script:eMailSubject = $Script:Configuration.Settings.Email.Subject
     $Script:SmtpServer = $Script:Configuration.Settings.Email.SmtpServer
        $Script:UserName = $Script:Configuration.Settings.Credentials.Username
     $Script:EncryptedPW = $Script:Configuration.Settings.Credentials.Password
     $Script:Base64String = $Script:Configuration.Settings.Credentials.Key   
        $ByteArray = [System.Convert]::FromBase64String($Base64String)
        $Script:Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $UserName, ($EncryptedPW | ConvertTo-SecureString -Key $ByteArray)
        #$Script:Password = $Credential.GetNetworkCredential().Password       #--[ Warning, exposes encrypted password ]--
    }
}

Function SendEmail {
    If ($Script:Debug){ $Script:eMailTo = $Script:DebugEmail }
 $msg = new-object System.Net.Mail.MailMessage
 $msg.From = $Script:eMailFrom
 $msg.To.Add("$Script:eMailTo")
 $msg.Subject = $Script:eMailSubject
 $msg.IsBodyHtml = $Script:eMailHTML
 $msg.Body = $Script:EmailBody 
 $ErrorActionPreference = "silentlycontinue"
 $smtp = new-object System.Net.Mail.SmtpClient($Script:SmtpServer)
    $smtp.Send($msg)
    If ($Console){Write-Host "--- Email Sent ---" -ForegroundColor White } 
}

#==[ Main Body ]================================================================
$DayOfWeek = (get-date).DayOfWeek
$StartTime = [datetime]::Now
#$domain = (Get-ADDomain).DNSroot      #--[ Optional.  Pulled from config file. ]--
$Script:Message = ""
$Target = ""
$Local = $False
$ScriptName = ($MyInvocation.MyCommand.Name).split(".")[0] 
$Script:LogFile = "$PSScriptRoot\$ScriptName-{0:MM-dd-yyyy_HHmmss}.html" -f (Get-Date)  
$Script:ConfigFile = "$PSScriptRoot\$ScriptName.xml"  

LoadConfig 
LoadModules

#--[ For testing only ]------------
#$Debug = $true
#$Console = $true
#----------------------------------

If ($Script:Debug){
 If ($Console){Write-Host  "===================== DEBUG MODE ENABLED =============================" -ForegroundColor Red }
 #TargetList = Get-ADComputer -Filter {Server -eq $Script:DebugTarget} -Property * | select name | sort name
    $TargetList = Get-ADComputer -Properties * -Filter * | where {$_.name -like $Script:DebugTarget} 
    If ($TargetList.count -lt 1){
        $Script:EmailBody = "-- Debug Mode Enabled --<br><br>"
        $Msg = "`nThe registry key check script found NO valid systems to scan.  `nDouble check your system list specification in the config file."
        If ($Console){Write-Host $Msg -ForegroundColor Red }
        $Script:EmailBody += $Msg
        $Script:EmailBody += "<br>The current specification = "+$Script:DebugTarget
        SendEmail
        break
    }
}Else{
 #$TargetList = Get-ADComputer -Filter * | ForEach-Object {$_.Name}
 $TargetList = Get-ADComputer -Filter {OperatingSystem -Like "*Windows*"} -Property * | select name | sort name
}

$FontFamily = "Consolas"   #--[ Use to change the font ]--

$Script:FontDarkCyan = '<span style="display:inline;font-family:'+$FontFamily+';size:7pt;color:#008B8B;margin-top:0px;margin-bottom:0px;">'
$Script:FontBlack = '<span style="display:inline;font-family:'+$FontFamily+';size:7pt;color:#000000;margin-top:0px;margin-bottom:0px;">'
$Script:FontRed = '<span style="display:inline;font-family:'+$FontFamily+';size:7pt;color:#ff0000;margin-top:0px;margin-bottom:0px;">'
$Script:FontDarkRed = '<span style="display:inline;font-family:'+$FontFamily+';size:7pt;color:#990000;margin-top:0px;margin-bottom:0px;">'
$Script:FontGreen = '<span style="display:inline;font-family:'+$FontFamily+';size:7pt;color:#00ff00;margin-top:0px;margin-bottom:0px;">'
$Script:FontDarkGreen = '<span style="display:inline;font-family:'+$FontFamily+';size:7pt;color:#009900;margin-top:0px;margin-bottom:0px;">'
$Script:FontDimGray = '<span style="display:inline;font-family:'+$FontFamily+';size:7pt;color:#696969;margin-top:0px;margin-bottom:0px;">'
$Script:FontYellow = '<span style="display:inline;font-family:'+$FontFamily+';size:7pt;color:#ffff00;margin-top:0px;margin-bottom:0px;">'

$Script:EmailBody = $Script:FontBlack +"Below is a record of the status of the "+ $Script:CompanyName +" custom registry key.  Entries are coded to reduce report size.<br>"
$Script:EmailBody += "<br><font size=2 color=gray>Coding key:<br>"
$Script:EmailBody += "B = Base RegKey. (Red means it was created, Green means it was detected)<br>O = OK.  Value exists and there is some data in it."
$Script:EmailBody += "  No new updates found.<br>C = Created missing value with default data of ""-"".<br>U = Found an existing value and an update.  Updated with new data." 
$Script:EmailBody += "<br>See end of email for list of keys in the order that they are inspected.<br></font>"

$NewValue = ""
$ValueList = @(             #--[ Adjust this list as suits your environment ]--
    "Approved Local Admins",
    "Approved RDP Access",
 "Asset Tag",
 "Assigned User",
 "Auto Logon",
 "Backup Schedule",
    "Build Date",
    "Build Validation",
    "Clean",
 "Custom 1",
 "Custom 2",
    "Custom 3",    
 "Group",
 "IE Version",
 "Java Protected",
 "Location",
 "Product Key",
    "Purge",
    "RSAT User",
 "Security Posture",
    "Serial Number",
    "XML Parser Version",
    "Z-Notes"
)

ForEach ($Target in $TargetList){
    $Failure = $false
 $Target = ($Target.name).ToUpper()

 If ($Console){
  Write-Host "`n`n==[ "  -ForegroundColor Cyan -NoNewline 
  Write-Host "Target: $Target " -NoNewline 
  Write-Host "]===============================================`n" -ForegroundColor Cyan 
 }
 $Script:EmailBody = $Script:EmailBody + $Script:FontDarkCyan+'<br>'+$Target+'</span>' 
    $Local = $False
    If ($Target -eq $Env:ComputerName){
        If ($Console){Write-Host "Local PC - No Ping test..." -ForegroundColor Green }
        $Script:EmailBody = $Script:EmailBody + $Script:FontDarkGreen+'<font color="black">--</font>LocalPC<font color="black">--</font></span>' 
        $Local = $true
        Try{
            $Result = Test-Path -Path $Script:RegistryPath -ErrorAction "stop"            
        }Catch{
            $ErrorMsg =$_.Exception.Message
            #$ErrorMsg       #--[ Optional ]--
        }
    }Else{
     If(Test-Connection -ComputerName $Target -count 1 -BufferSize 16 -ErrorAction SilentlyContinue ){
      If ($Console){Write-Host "Ping test OK..." -ForegroundColor Green }
      $Script:EmailBody = $Script:EmailBody + $Script:FontDarkGreen+'<font color="black">--</font>PingOK<font color="black">--</font></span>' 
            Try{
                $Result = Invoke-command -ComputerName $Target -Authentication default -Credential $Credential -ScriptBlock { 
                    test-path -Path $Using:RegistryPath -ErrorAction "stop"
                }
            }Catch{
                $ErrorMsg =$_.Exception.Message
                #$ErrorMsg       #--[ Optional ]--
            }
        }Else{
      If ($Console){Write-Host "Ping test FAILED..." -ForegroundColor Red }
            $Script:EmailBody = $Script:EmailBody +'<font color="black";font-family:Consolas;>--</font>'+$Script:FontDarkRed+'Unable to ping target.<font color="black">--</font></span>'
            $Failure = $true
        }
    }    

    If (!($Failure)){
        If ($Result){
            If ($Script:Console){Write-Host "Base Key Detected" -ForegroundColor Green }
            $Script:EmailBody += $Script:FontDarkGreen+'B</span>'
        }Else{
            If ($Script:Console){Write-Host "Creating Base Key" -ForegroundColor Red}
            $Script:EmailBody += $Script:FontDarkRed+'B</span>'
            If($Local){
                Try{
                    New-Item -Path $Script:RegistryPath -Force | Out-Null
                }Catch{
                    $Failed = $True    
                    $ErrorMsg =$_.Exception.Message
                    #$ErrorMsg       #--[ Optional ]--            
                }
            }Else{
                Try{
                    $Result = Invoke-command -ComputerName $Target -Authentication default -Credential $Credential -ScriptBlock { 
                    New-Item -Path $Using:RegistryPath -Force | Out-Null
                    }
                }Catch{
                    $Failed = $True
                    $ErrorMsg =$_.Exception.Message
                    #$ErrorMsg       #--[ Optional ]--
                }
            }
            If ($Failed){
                $Script:EmailBody = $Script:EmailBody + $Script:FontDarkRed+'<font color="black";font-family:Consolas>--</font>Base Key FAIL<font color="black">--</font></span>'
                If ($Console){Write-Host "-- Base Key Detect/Create FAILED" -ForegroundColor Red }
                $Script:EmailBody += $Script:FontDarkRed+'B</span>'
            }
        }
        $Script:EmailBody += $Script:FontBlack+'--'

        #--[ Test for values ]----------------------------------------------
        Try{
            If ($Local){
                $Result = Get-ItemProperty -Path $Script:RegistryPath -ErrorAction "stop"   
            }Else{    
                $Result = Invoke-command -ComputerName $Target -Authentication default -Credential $Credential -ScriptBlock { 
                    Get-ItemProperty -Path $Using:RegistryPath -ErrorAction "stop"
                }
            }
        }Catch{
            $ErrorMsg =$_.Exception.Message
            #$ErrorMsg       #--[ Optional ]--
        }

        If ($Console){Write-Host "Checking Sub-Keys " -ForegroundColor Yellow -NoNewline}      
     ForEach ($Value in $ValueList){ 
            If ([string]::IsNullOrEmpty($Result.$Value)){
                If ($Console){Write-Host "*" -NoNewline -ForegroundColor Red }                       #--[ value does not exist, creating it ]--
                $Script:EmailBody = $Script:EmailBody + $Script:FontDarkRed+'C</span>'
                $NewResult = Invoke-command -ComputerName $Target -Authentication default -Credential $Credential -ScriptBlock { 
                    New-ItemProperty -Path $Using:RegistryPath -Name $Using:Value -Value "-" -PropertyType STRING -Force | Out-Null
                }
            }Else{
                If ($Script:Update){
                    If ($Console){Write-Host "*" -NoNewline -ForegroundColor Yellow}                 #--[ value already exists but needs update ]--
                    $Script:EmailBody = $Script:EmailBody + $Script:FontDarkCyan+'U</span>'   
                    $NewResult = Invoke-command -ComputerName $Target -Authentication default -Credential $Credential -ScriptBlock { 
                        New-ItemProperty -Path $Using:RegistryPath -Name $Using:ValueName -Value $Using:NewValue -PropertyType STRING -Force | Out-Null
                    } 
                }Else{    
                    If ($Console){Write-Host "*" -NoNewline -ForegroundColor Green}                  #--[ value already exists ]--
                    $Script:EmailBody = $Script:EmailBody + $Script:FontDarkGreen+'O</span>'   
                }
            }
        }
    }
}

If ($Console){Write-Host "`n`n--- Run Completed ---" -ForegroundColor Cyan } 
$Script:EmailBody = $Script:EmailBody + $Script:FontRed+'<br><br>---Run Completed---' 

$Script:EmailBody = $Script:EmailBody +'<br><br><font color="gray";font-family:Consolas; size=2>The following keys are being checked/written according to the codes above:'
ForEach ($Value in $ValueList){
    $Script:EmailBody = $Script:EmailBody +'<br><font color="gray";size=2;font-family:Consolas>'+$Value+'</font></span>'
}

SendEmail

<#==[ XML Configuration file example.  Must reside in same folder as the script and be named like "scriptname.xml" ]=======================

<!-- Settings & Configuration File -->
<Settings>
 <General>
  <ReportName>Weekly Registry Key Refresh</ReportName>
  <DebugTarget>*PC85*</DebugTarget>
  <RegistryPath>HKLM:\Software\MyCompany</RegistryPath>
  <DnsServer>dc01</DnsServer>
  <Domain>MyCompany.com</Domain>
  <CompanyName>MyCompany</CompanyName>
 </General>
 <Email>
  <From>WeeklyReports@mycompany.com</From>
  <To>me@mycompany.com</To>
  <Debug>me@mycomapny.com</Debug>
  <Subject>Weekly Registry Key Refresh</Subject>
  <HTML>$true</HTML>
  <SmtpServer>100.100.50.5</SmtpServer>
 </Email>
 <Credentials>
  <UserName>mydomain\serviceaccount</UserName>
  <Password>76492d1NgA0AGEAMAAwADQAZgBiAGMAYQBhAG6AHoAIAegB2AHYgB2AHYAZQAxAGIATg11IAeAegB2AHYAZQAxAGIATgBaADcAYwBtAHAAWHwAYwAzADQABaADcAYwBtAHAAWQB6AHoAIAegB2AHYAZQQA9AIAZQQA9AIAegB2AHYAZ6AHoAIAegB2AHYAZQQA9AIAegB2AHYAZGUAZgBkAGYAZAA=</Password>
  <Key>kdhe8m+EhCh7HCh7HCvLOEyj2N0IObibCh7HCvLOEyj2N0IObiie8mE=</Key>
 </Credentials>
</Settings> 

#>
P
