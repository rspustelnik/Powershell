Get-ChildItem *.pgp | foreach-object {
    if (get-childitem out.file) { Remove-Item out.file ; rename-item $_ out.file -Force } else { Rename-Item $_ out.file -Force } 
    Get-ChildItem *.pgp | Out-Host
    Get-childitem *.file | Out-Host
}