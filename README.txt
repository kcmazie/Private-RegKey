# Private-RegKey
Sets a custom "private" registry key on all domain joined computers.  See full readme for details.

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
