# Azure Active Directory federation with G Suite
Azure Active Directory is the Identity Provider for Microsoft online services sich as Azure, Azure DevOps and Office 365. If you use another identity provider, you have to federate with Azure Active Directory using the B2B Collaboration feature in order to be able to use the identities you already have.
The `create_federation.ps1` script creates a direct federation from Azure Active Directory to a G Suite domain. The goal is to access Azure resources with users originating from the federated G Suite domain.


## Pre-Requisites
- Windows PowerShell (hence Windows)
- Windows PowerShell AzureADPreview module. The AzureADPreview module is installed by `create_federation.ps1`.

## Creating Federation
1.	Create custom SAML App in G Suite tenant:
-   Use ACS URL `https://login.microsoftonline.com/<aad tenant id>/saml2`
-   Use Entity ID `urn:federation:MicrosoftOnline`
2.  Export IDP metadata file e.g. `GoogleIDPMetadata-mybrand.io.xml` and place in same location as `create_federation.ps1`
3.  Add claim `http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress` with value <em>Basic Information</em> -> <em>Primary Email address</em>
4.  Enable the newly created G Suite SAML app (default state is OFF)
5.  Create federation by running `create_federation.ps1` with G Suite domain name as argument
6.  [Invite B2B Guest](https://docs.microsoft.com/en-us/azure/active-directory/b2b/add-users-administrator) users from the federated domain

## Notes
- There is a G Suite [Office 365 SAML App](https://support.google.com/a/answer/6363817?hl=en), which can be used instead of the custom SAML app. I did not use this app, as it attempts to auto-provisions users in the AAD tenant and I prefer this to be a AAD managed process instead.
- [Azure Active Directory Google federation](https://docs.microsoft.com/en-us/azure/active-directory/b2b/google-federation) is also in preview, but does not allow custom domains to be used (yet). Hence direct (SAML, WS-Fed) federation is used instead.

## Usage
Access the Azure Portal with using fully qualified url including AAD domain name in it e.g. `https://portal.azure.com/mybrand.onmicrosoft.com`.

## Limitations & Known Issue's
- The Azure [EA Portal](https://ea.azure.com) does not understand B2B accounts, so you can't sign in with Google identities there. However, you should be able to create Azure subscriptions with B2B accounts using [this method](https://docs.microsoft.com/en-us/azure/azure-resource-manager/grant-access-to-create-subscription). Note is is recommended to use (break glass) functional user accounts as Azure account owners.
- Setting up federation requires Windows PowerShell modules, hence Windows as OS (no PowerShell Core support unfortunately)
- This uses Azure Active Directory B2B Direct federation, which is in preview (i.e. limited SLA)
- I couldn't find a first party CLI for G Suite, so that (SAML app creation) part of the set up is manual

## Resources
- [Azure Active Directory B2B Documentation](https://docs.microsoft.com/en-us/azure/active-directory/b2b/)
- [Azure Active Directory management blade](https://portal.azure.com/#blade/Microsoft_AAD_IAM/ActiveDirectoryMenuBlade/Overview)
- [Azure Identity Management and access control security best practices](https://docs.microsoft.com/en-us/azure/security/fundamentals/identity-management-best-practices)
- [Direct federation with AD FS and third-party providers for guest users](https://docs.microsoft.com/en-us/azure/active-directory/b2b/direct-federation)
- [How Azure subscriptions are associated with Azure Active Directory](https://docs.microsoft.com/en-us/azure/active-directory/fundamentals/active-directory-how-subscriptions-associated-directory)
- [PowerShell Windows AzureADPreview module](https://docs.microsoft.com/en-us/powershell/module/azuread/?view=azureadps-2.0-preview)


## Disclaimer
This project is provided as-is, and may not necessarily be maintained