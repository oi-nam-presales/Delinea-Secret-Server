# Delinea-Secret-Server (DSS)

## Overview
PowerShell connector definition file was built with help of [PowerShell connector definition generating tool](https://connect.oneidentity.com/products/identity-manager/w/knowledge-base/738/powershell-connector-definition-generating-tool)
<img src="https://github.com/oi-nam-presales/Delinea-Secret-Server/assets/107265259/1dd9cc8d-b787-44dc-827b-6126987a7d47" width="600" height="500" />

File **OIMPSThycoticSecretServerConnector.json** contains metadata for the generating tool.  
File **OIMPSThycoticSecretServerConnector_PS.xml** - generated connector definition file.  
File **OIMPSThycoticSecretServerConnectorModule.psm1** contains all PowerShell code used in this connector.  
File **OIMPSThycoticSecretServerConnectorModule-TEST.ps1** contains PowerShell code for testing methods of the connector.  

PowerShell module can be debugged in VS Code.

## Supported objects and mappings:

|Mapping Name|Delinea Object (Schema Classes) |IM Object  |
|--|--|--|
|Department  | Department Folder  | Department |
|Department Department Folder | Folder | UNSGroupB |
| Group | Group | UNSGroupB |
| Personal Folder | Personal Folder  | UNSGroupB |
| Title Folder | TitleFolder | UNSGroupB |
| User | User | UNSAccountB |
||FolderPermission|Not Mapped|
||Role|Not Mapped|

## Target System Schema Classes
|Schema Class|Object Filter|
|--|--|
|Department Folder|**folderPath like '\\$TopLevelFolderName$%' and parentId='$TopLevelFolderId$' and id<>'$TopLevelFolderId$'**|
|Personal Folder|**folderPath like '\\$TopLevelPersonalFolderName$%' and parentId='$TopLevelPersonalFolderId$' and id<>'$TopLevelPersonalFolderId$'**|
|TitleFolder|**parentId<>'$TopLevelFolderId$' and id<>'$TopLevelFolderId$' and folderPath like '\\$TopLevelFolderName$%'**|
Where:
1. TopLevelFolderId = Id of the top level folder in the DSS
2. TopLevelFolderName = Name of the top level folder in the DSS (**Shared**)
3. TopLevelPersonalFolderName = **Personal**
4. TopLevelPersonalFolderId = ID of the "Personal" folder


## Operations
![Delinea Secret Server](https://github.com/oi-nam-presales/Delinea-Secret-Server/assets/107265259/11e3cdff-3f18-44a1-a2e0-8ca3f6b176c5)

## Configuration Parameters
|Parameter Full Path|Value|
|--|--|
|Custom\SecretServer\AdminGroupID|5|
|Custom\SecretServer\AdminGroupName|AdminRole-IT-XXXX|
|Custom\SecretServer\AzureUsersGroup|App-Thycotic-Users|
|Custom\SecretServer\BaseURL|https://xxxxxxx/SecretServer|
|Custom\SecretServer\DoDebug|true|
|Custom\SecretServer\GrantType|password|
|Custom\SecretServer\LogFolder|C:\Projects\Delinea\Logs|
|Custom\SecretServer\Password|************|
|Custom\SecretServer\PSModule|C:\Projects\Delinea\LatestWithFolders\OIMPSThycoticSecretServerConnectorModule.psm1|
|Custom\SecretServer\PVAccontDefName|Active Directory PV Account|
|Custom\SecretServer\RegularAccountDefinitionName|AAD Living Lab|
|Custom\SecretServer\SecretTemplateFields|username,password|
|Custom\SecretServer\SecretTemplateName|Azure AD Account|
|Custom\SecretServer\SyncProjectID|<Key><T>DPRProjectionStartInfo</T><P>CCC-FBF36B799565E2488D8ED86D11A5E5DB</P></Key>|
|Custom\SecretServer\TargetSystemName|DelineaSecretServer|
|Custom\SecretServer\TopFolderID|3|
|Custom\SecretServer\TopPersonalFolderId|4|
|Custom\SecretServer\Username|d-admin|

