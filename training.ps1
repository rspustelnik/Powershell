$token = 'glpat-2ReyRiZF4YDuC6F2wASm'
$header = @{
    'PRIVATE-TOKEN' = $token
}
$uri = 'https://gitlab.dillards.com/api/v4/projects/'
$projects = (Invoke-WebRequest -Headers $header -Uri $uri).Content | ConvertFrom-Json

$projects | select id, name
