Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

function New-MessageBox($Message) {
    $Result = [System.Windows.MessageBox]::Show($Message)
    return $Result

}
function New-Form($Name, $Height, $Width, $Text, $Position) {
    $Form = New-Object System.Windows.Forms.Form
    $Form.AutoSize = $true
    $Form.Name = $Name
    $Form.Size = New-Object System.Drawing.Size($Width, $Height)
    $Form.StartPosition = $Position
    $Form.Text = $Text
    $Form.Topmost = $true
    return $Form
}
function Show-Form($Form) {
    return $Form.ShowDialog()
}
function New-Label($Xpos, $Ypos, $Name, $Height, $Width, $Text, $Form) {
    $Label = New-Object System.Windows.Forms.Label
    $Label.Location = New-Object System.Drawing.Point($Ypos, $Xpos)
    $Label.Name = $Name
    $Label.Size = New-Object System.Drawing.Size($Width, $Height)
    $Label.Text = $Text
    $Form.Controls.Add($label)
    return $Label
}
function New-TextBox($Xpos, $Ypos, $Name, $Height, $Width, $Text, $Index, $Form) {
    $TextBox = New-Object System.Windows.Forms.TextBox
    $TextBox.Location = New-Object System.Drawing.Point($Ypos, $Xpos)
    $TextBox.Name = $Name
    $TextBox.Size = New-Object System.Drawing.Size($Width, $Height)
    $TextBox.TabIndex = $Index
    $TextBox.Text = $Text
    $Form.Controls.Add($TextBox)
    if ($Form.Controls.Name -contains $Name) { return $TextBox }else { $false }
}
function New-ListBox($Xpos, $Ypos, $Name, $Height, $Width, $Index, $OptArray, $Form) {
    $ListBox = New-Object System.Windows.Forms.ListBox
    $ListBox.Location = New-Object System.Drawing.Point($Ypos, $Xpos)
    $ListBox.Name = $Name
    $ListBox.Size = New-Object System.Drawing.Size($Width, $Height)
    $ListBox.TabIndex = $Index
    foreach ($item in $OptArray) {
        $ListBox.Items.Add($item)
    }
    $Form.Controls.Add($ListBox)
    return $ListBox    
}
function New-Button($Xpos, $Ypos, $Name, $Height, $Width, $Text, [switch]$OK, [switch]$Cancel, $Index, $Form) {
    $Button = New-Object System.Windows.Forms.Button
    $Button.Location = New-Object System.Drawing.Point($Ypos, $Xpos)
    $Button.Name = $Name
    $Button.Size = New-Object System.Drawing.Size($Width, $Height)
    $Button.TabIndex = $Index
    $Button.Text = $Text
    if ($OK) {
        $Button.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $form.AcceptButton = $Button
    }
    if ($Cancel) {
        $Button.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
        $form.CancelButton = $Button
    }
    $Form.Controls.Add($Button)
    return $Button
}
function Add-SANClick($Form) {
    $invis.AccessibleName = ($invis.AccessibleName -as [int]) + 1
    $invis.name = ($invis.name -as [int]) + 1
    $invis.text = ($invis.text -as [int]) + 22

    New-TextBox -Xpos ($invis.Text -as [int]) -Ypos 10 -Name "SanAddresss$($invis.name)" -Height 20 -Width 275 -Text "" -Index ($invis.AccessibleName -as [int]) -Form $Form 
}
#OK Function (all the work happens here)
function Add-OKClick($Form) {
    #Validate Method Listbox Selection
    if ( $null -ne $lstAction.selecteditem ) {
        $cn = $tbCN.Text
        $ou = $tbOU.Text
        #Validate FQDN and Department Name 
        if (-not ([string]::IsNullOrEmpty($ou)) -and -not ([string]::IsNullOrEmpty($cn))) {
            $sanx = $form.controls | Where-Object { $_.name -like "SanAddress*" } | ForEach-Object { return $_.text } | Select-Object -Unique
            $sanx = ('"' + ($sanx -join '","') + '"') -replace ',""', ''
            #Get-Certificate (Create Get-Certificate Command Line populated with correct Data, Currently paste it as a string, can run if OKed by Infosec)
            if ($lstAction.selecteditem -eq 'Get-Certificate') {
                $GCcertReq = "Get-Certificate -Template 'WebServerManualv1' -SubjectName 'CN=" + $tbCN.Text + ", OU=" + $tbOU.Text + ", O=Dillards Inc., L=Little Rock, S=Arkansas, C=US'  -DnsName " + $sanx + " -CertStoreLocation Cert:\LocalMachine\My -Url ldap: "
                write-host $GCcertReq
                #Close Form
                $Form.Dispose()
            } 
            #Certreq.exe (Created inf file, then runs certreq.exe generating a CSR, both INF and CSR are saved in Chosen Directory)
            if ($lstAction.selecteditem -eq 'Certreq.exe') {
                $infPath = New-Object System.Windows.Forms.SaveFileDialog
                $infPath.filter = "inf files (*.inf)| *.inf"
                $infPath.InitialDirectory = 'c:\'
                $Result = $infPath.ShowDialog() 
                if ($Result -ne 'Cancel') {
                    #Base INF template
                    $inf = @"
[NewRequest]
Subject = "CN=$cn, O=Dillard's Inc., OU=$ou, L=Little Rock, ST=Arkansas, C=US"
KeyLength =  2048
KeySpec = 1
Exportable = True
HashAlgorithm = SHA256
MachineKeySet = True
SMIME = False
UseExistingKeySet = False
RequestType = PKCS10
KeyUsage = 0xA0
Silent = True
FriendlyName = "Certificate SHA-256"
[EnhancedKeyUsageExtension]
OID=1.3.6.1.5.5.7.3.1
[Extensions]
2.5.29.17 = "{text}"
"@ 
                    #Loop through SAN fields (dynamic, allowing any number of SAN entries)
                    $sanx = $form.controls | Where-Object { $_.name -like "SanAddress*" }
                    $inf += $sanx.text | ForEach-Object { "`n_continue_ = `"dns=" + $_ + "`"" -replace '_continue_ = "dns="', $null }
                    $inf | Out-File -FilePath $infPath.FileName
                    $inf
                    #Command Line
                    certreq.exe -new ($infPath.FileName ) ($infPath.FileName + ".csr")
                    #Close Form
                    $Form.Dispose()
                }
                
            }
            if ($lstAction.selecteditem -eq 'OpenSSL') {
                New-MessageBox -message 'OpenSSL Not Implimented Yet!'
            }
        }
        else {
            New-MessageBox -message 'CN and OU are required!'
        }
    }
    else {
        New-MessageBox -message 'Please Select a Cert Method'
    }
}
#CANCEL Function
function Add-CANCELClick($Form) {
    $form.Dispose()
}

#Main
#Variables
[int]$FormHeight = 250
[int]$FormWidth = 420
$FormName = 'Certificate Request Form'
#this adds the extended functionality not approved by infoxsec at this point.
#$MethodOptions = "Get-Certificate", "Certreq.exe", "OpenSSL"
$MethodOptions = "Certreq.exe"
$Position = 'CenterScreen'
$Screen = [system.windows.forms.screen]::PrimaryScreen
$Text = 'Certificate Request Form'

#Create Main Form
$frmMain = New-Form -Name $FormName -Height $FormHeight -Width $FormWidth -Text $Text -Position $Position
$frmMain.MaximumSize = New-Object System.Drawing.Size($FormWidth, $screen.bounds.height)

#FQDN Textbox
$lblCN = New-Label -Xpos ($frmMain.top + 10) -Ypos 10 -Name 'lblCN' -Height 15 -Width 275 -Text 'Fully Qualified Domain Name:' -Form $frmMain
$tbCN = New-TextBox -Xpos ($lblCN.bottom + 5) -Ypos 10 -Name 'tbCN' -Height 20 -Width 275 -Text '' -Index 0 -Form $frmMain

#Department Name Textbox
$lblOU = New-Label -Xpos ($tbCN.bottom + 7) -Ypos 10 -Name 'lblOU' -Height 15 -Width 275 -Text 'Department Name:' -Form $frmMain
$tbOU = New-TextBox -Xpos ($lblOU.bottom + 5) -Ypos 10 -Name 'tbOU' -Height 20 -Width 275 -Text '' -Index 1 -Form $frmMain

#Inivisble object for Storing variables between button Clicks
$invis = New-Label -text $($tbOU.bottom + 5).ToString() -Name 0 -AN 1 -Form $frmMain -Xpos $lblSAN.Bottom

#First SAN Text Box
$lblSAN = New-Label -Xpos ($tbOU.bottom + 7) -Ypos 10 -Name 'lblSAN' -Height 15 -Width 275 -Text 'Alternative Names and URLs:' -Form $frmMain
Add-SANClick -Form $frmMain | Out-Null

#Button to Add Additional Subject Alternative Name Field
$btnAddSan = New-Button -Xpos (10) -Ypos ($FormWidth - 120) -Name "OK" -Height 75 -Width 100 -Text "Add Alternative Name" -Index 97  -Form $frmMain    
$btnAddSan.Add_Click( { Add-SANClick -form $frmMain })

#Method Listbox
$lstAction = New-ListBox -Xpos ($btnAddSan.Bottom + 10) -Ypos ($FormWidth - 120) -Name "listCmd" -Height 100 -Width 100 -Index 97 -OptArray $MethodOptions  -Form $frmMain

#CANCEL
$btnCancel = New-Button -Xpos ($frmMain.bottom - 30) -Ypos ($FormWidth - 120) -Name "CANCEL" -Height 25 -Width 100 -Text "CANCEL"  -Index 100 -Form $frmMain
$btnCancel.Add_Click( { Add-CANCELClick -Form $frmMain })

#OK
$btnOK = New-Button -Xpos ($btnCancel.top - 25) -Ypos ($FormWidth - 120) -Name "OK" -Height 25 -Width 100 -Text "OK" -Index 99  -Form $frmMain
$btnOK.Add_Click( { Add-OKClick -Form $frmMain })



[void] $frmMain.ShowDialog()
