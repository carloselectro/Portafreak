# Portafreak
Useful powershell scripts that I made to monitor active asterisk Call.
Tested with Assterisk 16 in PJSIP.

Edit /etc/asterisk/manager.conf

[general]
enabled = yes
webenabled = no
port = 5038
bindaddr = 0.0.0.0

[User]
secret = my password
read = agent
write = command,system

Execute the script:

C:\Windows\SysWOW64\WindowsPowerShell\v1.0\Powershell.exe -executionpolicy bypass -file "D:\Powershell\Asterisk_active_channel_AMI.ps1" -asterisk_ip "X.X.X.X" -Port "5038" -external_context "TO_EXTERNAL" -ami_user "User" -ami_pass "my_password"

