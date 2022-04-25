$cid="946058"
$url_main="https://api.meraki.com/api/v0/organizations/$cid/deviceStatuses"
$security_token=""
$header = @{'X-Cisco-Meraki-API-Key'=$security_token}
$apiDataRaw=Invoke-WebRequest -Headers $header   -Method Get   -Uri $url_main   
$apiDataObj = ConvertFrom-Json $apiDataRaw.Content
$offline = $apiDataObj|Where-Object{$_.status -eq "offline"}
$offline.name
$offline.count
