$url_main = "https://gitlab.dillards.com/api/v4/users?state=active"
$security_token = "glpat-2ReyRiZF4YDuC6F2wASm"
$header = @{'PRIVATE-TOKEN' = $security_token }
$apiDataRaw = Invoke-WebRequest -Headers $header   -Method Get   -Uri $url_main 
