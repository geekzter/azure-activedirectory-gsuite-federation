# No shebang, as Windows only (AzureAD module requies Windows PowerShell)
<#
.SYNOPSIS 
    Creates a federation from Azure Active Directory to a G Suite domain

.EXAMPLE
    ./create_federation.ps1 -federationBrandName mybrand -federationDomain mybrand.io
#>
param ( 
    [parameter(Mandatory=$true)][string]$federationBrandName,
    [parameter(Mandatory=$true)][string]$federationDomain
) 

function AddorUpdateModule (
    [string]$moduleName
) {
    if (Get-InstalledModule $moduleName -ErrorAction SilentlyContinue) {
        $azModuleVersionString = Get-InstalledModule $moduleName | Sort-Object -Descending Version | Select-Object -First 1 -ExpandProperty Version
        $azModuleVersion = New-Object System.Version($azModuleVersionString)
        $azModuleUpdateVersionString = "{0}.{1}.{2}" -f $azModuleVersion.Major, $azModuleVersion.Minor, ($azModuleVersion.Build + 1)
        # Check whether newer module exists
        if (Find-Module $moduleName -MinimumVersion $azModuleUpdateVersionString -ErrorAction SilentlyContinue) {
            Write-Host "Windows PowerShell $moduleName module $azModuleVersionString is out of date. Updating Az modules..."
            Update-Module $moduleName -AcceptLicense -Force
        } else {
            Write-Host "Windows PowerShell $moduleName module $azModuleVersionString is up to date"
        }
    } else {
        # Install module if not present
        if (!(New-Object System.Security.Principal.WindowsPrincipal([System.Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole("Administrators")) {
            Write-Output "Not running as Administrator"
            exit
        }
        Write-Host "Installing Windows PowerShell $moduleName module..."
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -ForceBootstrap
        Install-Module $moduleName -Force -SkipPublisherCheck
    }
    Import-Module $moduleName
}

# Validation
if ($PSVersionTable.PSEdition -and ($PSVersionTable.PSEdition -ne "Desktop")) {
    Write-Output "This scripts is dependent on AzureAD module which requires Windows PowerShell"
    exit
}

$googleIDPMetadata="GoogleIDPMetadata-$federationDomain.xml"
if (!(Test-Path $googleIDPMetadata)) {
    Write-Host "Google IDP Metadata file $googleIDPMetadata not found, exiting"
    exit
}

$namespaces = @{ds="http://www.w3.org/2000/09/xmldsig#";md="urn:oasis:names:tc:SAML:2.0:metadata"}
$logonUrl  = Select-Xml -Path $googleIDPMetadata -Namespace $namespaces -XPath "//md:SingleSignOnService[@Binding='urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect']/@Location" | Select-Object -ExpandProperty Node | Select-Object -ExpandProperty Value
$issuerUrl = Select-Xml -Path $googleIDPMetadata -Namespace $namespaces -XPath "//md:EntityDescriptor/@entityID" | Select-Object -ExpandProperty Node | Select-Object -ExpandProperty Value
$certData  = Select-Xml -Path $googleIDPMetadata -Namespace $namespaces -XPath "//ds:X509Certificate" | Select-Object -ExpandProperty Node | Select-Object -ExpandProperty InnerXml

# Install AzureAD preview module
AddorUpdateModule AzureADPreview

# Connect to Azure Active Directory
try {
    $session = Get-AzureADCurrentSessionInfo -ErrorAction SilentlyContinue
} catch [Microsoft.Open.Azure.AD.CommonLibrary.AadNeedAuthenticationException] {
    $session = $null
}
if (!($session)) {
    Connect-AzureAD
}

# Determine whether federation already exists
try {
    $federationSettings = Get-AzureADExternalDomainFederation -ExternalDomainName $federationDomain -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FederationSettings
} catch [Microsoft.Open.AzureADBeta.Client.ApiException] {
    $federationSettings = $null
}
if ($federationSettings) {
    Write-Host "`nThere is already a federation in place for ${federationDomain}:"
    $federationSettings | Format-List
    exit
}

# https://docs.microsoft.com/en-us/powershell/module/azuread/new-azureadexternaldomainfederation?view=azureadps-2.0-preview
$federationSettings = New-Object Microsoft.Open.AzureAD.Model.DomainFederationSettings
$federationSettings.ActiveLogOnUri = $logonUrl # SSO URL from step 2 of GSuite app set-up
$federationSettings.IssuerUri = $issuerUrl # Entity ID from step 2 of GSuite app set-up
$federationSettings.LogOffUri = $federationSettings.ActiveLogOnUri
$federationSettings.FederationBrandName = $federationBrandName
# MetadataExchangeUri required but makes no sense so this is a dummy value
$federationSettings.MetadataExchangeUri = "https://$federationDomain/adfs/services/trust/mex" # Dummy value
$federationSettings.PassiveLogOnUri = $federationSettings.ActiveLogOnUri
$federationSettings.PreferredAuthenticationProtocol = "SamlP"
# Signing cert from X509Certificate in downloaded Gsuite metadata
$federationSettings.SigningCertificate = $certData
$federationSettings | Format-List

# Prompt to continue
$proceedanswer = Read-Host "`nIf you wish to proceed implementing federation from $($session.TenantDomain) with $federationDomain, please reply 'yes' - null or N aborts"

if ($proceedanswer -ne "yes") {
    Write-Host "`nReply is not 'yes' - Aborting " -ForegroundColor Red
    exit
}

New-AzureADExternalDomainFederation -ExternalDomainName "$federationDomain" -FederationSettings $federationSettings

Write-Host "Users from $federationDomain should access the Azure Portal using this link: https://portal.azure.com/$($session.TenantDomain)"
