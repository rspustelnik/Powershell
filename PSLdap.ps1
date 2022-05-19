Add-Type -AssemblyName System.DirectoryServices.Protocols
Set-Alias -Name Get-LdapConfig -Value initLdap
#Builds Ldap config file

#* Set-LdapConfig configures your LDAP connection information and saves it in your local User Profile
function Set-LdapConfig {   
    param(
        [Parameter(Mandatory = $false)][string]$username,
        [Parameter(Mandatory = $false)][string]$server ,
        [Parameter(Mandatory = $false)][string]$port ,
        [Parameter(Mandatory = $false)][string]$ldapSearchBase        
    )
    if ($username) { $password = (Get-Credential -UserName $username).Password | Convertfrom-SecureString }
    else {
        $User = read-host -Prompt "DN"
        $password = ConvertTo-SecureString $(read-host -Prompt "PW") -AsPlainText -Force
        $Creds = New-Object System.Management.Automation.PSCredential ($User, $password)
        $username = $creds.UserName
        $password = $creds.Password | ConvertFrom-SecureString 
    }
    $server = if (!$server) { Read-Host -Prompt "Ldap Server" }
    $port = if (!$port) { Read-Host -Prompt "Ldap Port" }
    $ldapSearchBase = if (!$ldapSearchBase) { Read-Host -Prompt "Ldap Search Base" }
    @{
        username       = $username;
        password       = $password;
        server         = $server;
        port           = $port;
        ldapSearchBase = $ldapSearchBase
    } | ConvertTo-Json | Set-Content "$($env:USERPROFILE)\PSLdapConfig.json"
    
}
 
#* Set-LdapAttribute Set or Delete Ldap any Attribute 
function Set-LdapAttribute {
    param(
        [Parameter(Mandatory = $true)][string]$AttrName,
        [Parameter(Mandatory = $false)][string]$AttrValue,
        [Parameter(Mandatory = $true)][ValidateSet("add", "replace", "delete")][string]$AttrAction,
        [Parameter(Mandatory = $true)][object]$ldapObject
    )
    $settings = initLdap
    [byte]$byte = "0x1"
    $control = New-Object 'System.DirectoryServices.Protocols.DirectoryControl' -ArgumentList '1.3.18.0.2.10.15', $byte, $true, $true
    $request = New-Object -TypeName System.DirectoryServices.Protocols.ModifyRequest
    $ldapCredentials = New-Object System.Net.NetworkCredential($settings.username, $settings.password)
    $ldapConnection = New-Object System.DirectoryServices.Protocols.LDAPConnection("$($settings.server):$($settings.port)", $ldapCredentials, "Basic")
    $ldapConnection.Timeout = new-timespan -Seconds 1800 
    $ldapConnection.SessionOptions.ProtocolVersion = 3
    $DirectoryRequest_value = New-Object "System.DirectoryServices.Protocols.DirectoryAttributeModification"
    $DirectoryRequest_value.Name = $AttrName
    switch ($AttrAction) {
        add {
            $DirectoryRequest_value.Operation = [System.DirectoryServices.Protocols.DirectoryAttributeOperation]::Add
        }
        replace {
            $DirectoryRequest_value.Operation = [System.DirectoryServices.Protocols.DirectoryAttributeOperation]::Replace
        }
        delete { 
            $DirectoryRequest_value.Operation = [System.DirectoryServices.Protocols.DirectoryAttributeOperation]::Delete 
        }
    }
    $request.DistinguishedName = $ldapObject.DistinguishedName
    $request.Controls.Add($control) | out-null
    $request.Modifications.Add($DirectoryRequest_value) | out-null
    return $ldapConnection.SendRequest($request)
}

#* initLdap is a Procedural function called by other commands. Also Aliased as get-ldapconfig it outputs the current saved configuration
function initLdap {
    $settings = Get-Content "$($env:USERPROFILE)\PSLdapConfig.json" | ConvertFrom-Json
    $settings.password = ($settings.password | ConvertTo-SecureString )
    return $settings
}

#* Get-LdapObject will retrieve any object from the LDAP repo via the search filter.
function Get-LdapObject {
    [CmdletBinding()]
    param (
        [Parameter()][string]$ldapSearchFilter,
        [Parameter(Mandatory = $false)][string[]]$excludeProperty = ''
    )
    $settings = initLdap
    $ldapCredentials = New-Object System.Net.NetworkCredential($settings.username, $settings.password)
    $ldapConnection = New-Object System.DirectoryServices.Protocols.LDAPConnection("$($settings.server):$($settings.port)", $ldapCredentials, "Basic")
    $ldapConnection.Timeout = new-timespan -Seconds 1800
    if ($excludeProperty) {
        $Arguments = @{
            LdapConnection  = $ldapConnection 
            LdapFilter      = $ldapSearchFilter 
            SearchBase      = $settings.ldapSearchBase 
            Scope           = 'Subtree' 
            excludeProperty = $excludeProperty 
            Property        = '*', '+'
        }
    }
    else {
        $Arguments = @{
            LdapConnection = $ldapConnection 
            LdapFilter     = $ldapSearchFilter 
            SearchBase     = $settings.ldapSearchBase 
            Scope          = 'Subtree' 
            Property       = '*', '+'
        }
    }
    
    return Get-LdapObjectRaw @Arguments
    
    
}
#* ConvertTo-Object converts the Hashtable returned from the LDAP server from Byte[] to an Object
function ConvertTo-Object {
    # Parameter help description
    param (
        [Parameter(Mandatory = $false)][string[]]$excludeProperty,
        [Parameter(Mandatory, ValueFromPipeline)][hashtable]$Hash
    )
    begin { $object = New-Object Object }
    
    process {
    
        $_.GetEnumerator() | ForEach-Object { 
            $arguments = @{
                inputObject = $object
                memberType  = 'NoteProperty'
                name        = $_.Name
                value       = $_.value
            }
            if ($excludeProperty) {
                if (!$excludeProperty.Contains($_.Name)) { Add-Member @arguments }
            }
            else {
                Add-Member @arguments
            }
        } 
    }  
    end { $object }
}

#* Get-LdapObjectRaw is the Background Function used to retrieve unformated Data from the Ldap Server
function Get-LdapObjectRaw {
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
        [Parameter(Mandatory = $false)][String[]] $excludeProperty,
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
        if ($Property) {
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
        return $response
    }
}

#* Expand-Colection is a recursive background function used to process objects with sub-objects
function Expand-Collection {
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
            $i | ForEach-Object { $_ }
        }
    }
}

#* Unlock-LdapUser deletes the pwdFailureTime and pwdAccountLockedTime values from a user Record
function Unlock-LDAPUser ($LDAPUser) {
    if ($LDAPUser.GetType().name -eq 'Object') { $LDAPObject = $LDAPUser } else { $LDAPObject = Get-LdapUser -UserID $LDAPUser }
    if (set-LdapAttribute -AttrName 'pwdFailureTime' -AttrValue '' -ldapObject $LDAPObject -AttrAction delete ) { 
        write-host -ForegroundColor Green "pwdFailureTime : Success" 
    }
    else { write-host -ForegroundColor red "pwdFailureTime : Failed" }
    if (set-LdapAttribute -AttrName 'pwdAccountLockedTime' -AttrValue '' -ldapObject $LDAPObject -AttrAction delete ) {
        write-host -ForegroundColor Green "pwdAccountLockedTime : Success"
    }
    else {
        write-host -ForegroundColor red "pwdAccountLockedTime : Failed"
    }
}

#* Get-LdapUser gets a user record via their username as a string
function Get-LdapUser {
    param (
        [Parameter(Mandatory)][String] $UserID,    
        [Parameter(Mandatory = $false)][String[]] $excludeProperty        
    )
    if ($excludeProperty) {
        $options = @{
            ldapSearchFilter = "(&(objectClass=*)(uid=$UserID))"
            excludeProperty  = $excludeProperty 
        }
    } 
    else { 
        $options = @{
            ldapSearchFilter = "(&(objectClass=*)(uid=$UserID))"
        }
    }
    return Get-LdapObject @options
}