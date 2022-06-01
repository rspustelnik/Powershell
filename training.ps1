(Get-ADGroupMember vendors).samaccountname | % {
    $vendorid = $_
    if ((Get-ADuser $vendorid -Properties memberof).memberof -contains 'CN=GlobalProtectAllowed,OU=Groups,OU=DDSUsers,DC=dds,DC=dillards,DC=net') { $vendorid }
}
