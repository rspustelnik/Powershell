(Get-ADGroupMember vendors).samaccountname | ? { (Get-ADuser $_ -Properties memberof).memberof -contains 'CN=GlobalProtectAllowed,OU=Groups,OU=DDSUsers,DC=dds,DC=dillards,DC=net' }

