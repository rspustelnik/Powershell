Add-Type -AssemblyName System.DirectoryServices.Protocols


#Builds Ldap config file
function Set-LdapConfig {   
    param(
        [Parameter(Mandatory = $false)][string]$username,
        [Parameter(Mandatory = $false)][string]$server ,
        [Parameter(Mandatory = $false)][string]$port ,
        [Parameter(Mandatory = $false)][string]$ldapSearchBase        
    )
    if ($username) { $password = (Get-Credential -UserName $username).Password | Convertfrom-SecureString }
    else {
        $creds = Get-Credential -Message "DN/PW"
        $username = $creds.UserName
        $password = $creds.Password | ConvertFrom-SecureString 
    }
    $server = $server ? $server : (Read-Host -Prompt "Ldap Server")
    $port = $port ? $port : (Read-Host -Prompt "Ldap Port")
    $ldapSearchBase = $ldapSearchBase ? $ldapSearchBase : (Read-Host -Prompt "Ldap Search Base")
    @{
        username       = $username;
        password       = $password;
        server         = $server;
        port           = $port;
        ldapSearchBase = $ldapSearchBase
    } | ConvertTo-Json | Set-Content .\PSLdapConfig.json
    
}
#Set or Delete Ldap Attribute
function Set-LdapAttribute {
    param(
        [Parameter(Mandatory = $true)][string]$AttrName,
        [Parameter(Mandatory = $true)][string]$AttrValue,
        [Parameter(Mandatory = $true)][ValidateSet("add", "replace", "delete")][string]$AttrAction,
        [Parameter(Mandatory = $true)][object]$ldapUser
    )
    $settings = initLdap
    $ldapCredentials = New-Object System.Net.NetworkCredential($settings.username, $settings.password)
    $ldapConnection = New-Object System.DirectoryServices.Protocols.LDAPConnection("$($settings.server):$($settings.port)", $ldapCredentials, "Basic")
    $ldapConnection.Timeout = new-timespan -Seconds 1800 
    $DirectoryRequest_value = New-Object "System.DirectoryServices.Protocols.DirectoryAttributeModification"
    $DirectoryRequest_value.Name = $AttrName

    switch ($AttrAction) {
        add { $DirectoryRequest_value.Operation = [System.DirectoryServices.Protocols.DirectoryAttributeOperation]::Add }
        replace { $DirectoryRequest_value.Operation = [System.DirectoryServices.Protocols.DirectoryAttributeOperation]::Replace }
        delete { $DirectoryRequest_value.Operation = [System.DirectoryServices.Protocols.DirectoryAttributeOperation]::Delete }
    }
    
    $DirectoryRequest_value.Add($AttrValue) |out-null
    $request = New-Object -TypeName System.DirectoryServices.Protocols.ModifyRequest
    $request.DistinguishedName = $ldapUser.DistinguishedName
    $request.Modifications.Add($DirectoryRequest_value) | out-null
    return $ldapConnection.SendRequest($request)
}
function initLdap {
    $settings = Get-Content .\PSLdapConfig.json | ConvertFrom-Json
    $settings.password = ($settings.password | ConvertTo-SecureString )
    return $settings
}
function Get-LdapUser {
    [CmdletBinding()]
    param (
        [Parameter()][string]$ldapSearchFilter,
        [Parameter(Mandatory=$false)][string]$excludeProperty = ''
    )
    $settings = initLdap
    $ldapCredentials = New-Object System.Net.NetworkCredential($settings.username, $settings.password)
    $ldapConnection = New-Object System.DirectoryServices.Protocols.LDAPConnection("$($settings.server):$($settings.port)", $ldapCredentials, "Basic")
    $ldapConnection.Timeout = new-timespan -Seconds 1800
    return ($excludeProperty ? (Get-LdapObject -LdapConnection $ldapConnection -LdapFilter $ldapSearchFilter -SearchBase $settings.ldapSearchBase -Scope Subtree -excludeProperty $excludeProperty):(Get-LdapObject -LdapConnection $ldapConnection -LdapFilter $ldapSearchFilter -SearchBase $settings.ldapSearchBase -Scope Subtree))
    
}
function ConvertTo-Object {
    # Parameter help description
    param (
        [Parameter(Mandatory = $false)][string]$excludeProperty,
        [Parameter(Mandatory,ValueFromPipeline)][hashtable]$Hash
    )

    begin { $object = New-Object Object }
    
    process {
    
        $_.GetEnumerator() | ForEach-Object { $_.name -eq $excludeProperty ? $null : (Add-Member -inputObject $object -memberType NoteProperty -name $_.Name -value $_.Value) }  
    
    }
    
    end { $object }
    
}
function Get-LdapObject {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [System.DirectoryServices.Protocols.LdapConnection] $LdapConnection,

        [Parameter(ParameterSetName = 'DistinguishedName',
            Mandatory)]
        [String] $Identity,

        [Parameter(ParameterSetName = 'LdapFilter',
            Mandatory)]
        [Alias('Filter')]
        [String] $LdapFilter,

        [Parameter(ParameterSetName = 'LdapFilter',
            Mandatory)]
        [String] $SearchBase,

        [Parameter(Mandatory=$false)][String] $excludeProperty,

        [Parameter(ParameterSetName = 'LdapFilter')]
        [System.DirectoryServices.Protocols.SearchScope] $Scope = [System.DirectoryServices.Protocols.SearchScope]::Subtree,

        [Parameter()]
        [String[]] $Property,

        [Parameter()]
        [ValidateSet('String', 'ByteArray')]
        [String] $AttributeFormat = 'String',

        # Do not attempt to clean up the LDAP output - provide the output as-is
        [Parameter()]
        [Switch] $Raw
    )

    begin {
        if ($AttributeFormat -eq 'String') {
            $attrType = [string]
        }
        else {
            $attrType = [byte[]]
        }
    }

    process {
        $request = New-Object -TypeName System.DirectoryServices.Protocols.SearchRequest

        if ($PSCmdlet.ParameterSetName -eq 'DistinguishedName') {
            $request.DistinguishedName = $Identity
        }
        else {
            $request.Filter = $LdapFilter
            $request.DistinguishedName = $SearchBase
        }

        if (-not $Property -or $Property -contains '*') {
        }
        else {
            foreach ($p in $Property) {
                [void] $request.Attributes.Add($p)
            }
        }

        $response = $LdapConnection.SendRequest($request)

        if (-not $response) {
            "No response was returned from the LDAP server."
            return
        }

        if ($response.ResultCode -eq 'Success') {
            if ($Raw) {
                $($response.Entries)
            }
            else {
                # Convert results to a PSCustomObject.
                foreach ($e in $response.Entries) {
                    $hash = @{
                        PSTypeName        = 'LdapObject'
                        DistinguishedName = $e.DistinguishedName
                    }
                    foreach ($a in $e.Attributes.Keys | Sort-Object) {
                        $hash[$a] = $e.Attributes[$a].GetValues($attrType) | Expand-Collection
                    }

                    $outhash = $hash | ConvertTo-Object -excludeProperty $excludeProperty 
                }
                return $outhash
            }
        }

        $response
    }
}
function Expand-Collection {
    # Simple helper function to expand a collection into a PowerShell array.
    # The advantage to this is that if it's a collection with a single element,
    # PowerShell will automatically parse that as a single entry.
    [CmdletBinding()]
    param(
        [Parameter(Mandatory,
            Position = 0,
            ValueFromPipeline,
            ValueFromRemainingArguments)]
        [ValidateNotNull()]
        [Object[]] $InputObject
    )

    process {
        foreach ($i in $InputObject) {
            ForEach-Object -InputObject $i -Process { $_ }
        }
    }
}