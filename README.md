# Portafreak
A useful powershell script that I made to monitor active asterisk calls.
The script connect to the AMI.
Tested with Asterisk 16 in PJSIP.

Edit /etc/asterisk/manager.conf.
DO NOT FORGET TO CHOOSE A GOOD PASSWORD.

[general]
enabled = yes
webenabled = no
port = 5038
bindaddr = 0.0.0.0

[User]
secret = my password
read = agent
write = command,system

Execute the script in command line:

C:\Windows\SysWOW64\WindowsPowerShell\v1.0\Powershell.exe -executionpolicy bypass -noexit "D:\Powershell\Asterisk_active_channel_AMI.ps1" -asterisk_ip "X.X.X.X" -Port "5038" -external_context "TO_EXTERNAL" -ami_user "User" -ami_pass "my password"

Here's a screenshot of the gridview's output. Data has been blurred for confidentiality.

![Alt text]( https://i.imgur.com/e5NXooj.png "Gridview")
