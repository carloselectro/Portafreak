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


