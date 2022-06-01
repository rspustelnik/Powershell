(Get-ADGroupMember vendors).samaccountname | % {
    $vendorid = $_
    Get-ADGroupMember globalprotectallowed | ?($_.samaccountname -eq $vendorid)
}
