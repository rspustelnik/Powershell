Get-ChildItem *.pgp | foreach-object {
    if (get-childitem out.file) { Remove-Item out.file }else { Rename-Item $_ out.file -Force } 
    Get-ChildItem *.pgp
    get-childitem *.file
}