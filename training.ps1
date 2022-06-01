(Get-ADGroupMember vendors).samaccountname | ? { (get-ADuser $_ -Properties memberof).memberof -notcontains 'CN=GlobalProtectAllowed,OU=Groups,OU=DDSUsers,DC=dds,DC=dillards,DC=net' }

