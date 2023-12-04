Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

#$ScriptPath = Split-Path $MyInvocation.MyCommand.Path

#Import-Module -Name $("$ScriptPath\OIMPSConnectConnectorModule.psm1") -Force

Import-Module -Name $PSScriptRoot\OIMPSThycoticSecretServerConnectorModule.psm1 -Force

$Username = "d-admin" #"viloun.viengluang@quest.com"  #"paul.sherman@quest.com" #"OneIdentityPOC"
$Password = "0neIdentity!" #"OneIdentity!"  #"0neL0gin!" #"YMU3bhc2mgb-bry1xtd"
$BaseURL =  "https://dc01.oneidentity.demo/SecretServer" #"https://presales.secretservercloud.com"  #"https://cbocs-secrets.secretservercloud.com"
$GrantType = "password"
$LogFolder = "C:\Projects\Delinea\Logs"
$DoDebug = "true"

try{

	SetParameters -BaseURL $BaseURL `
					-Username $Username `
					-Password $Password `
					-GrantType $GrantType `
					-LogFolder $LogFolder `
					-DoDebug $DoDebug

	#$template = TemplateGetByName -name "One Identity Secrets" #"One Identity Admin User"
				
	#$secret = SecretCreate -secretName "Test User8 Secret" -templateName "One Identity Secrets" -templateFieldName "One Identity Login" -folderId 57 -value "MyTestPassword!1"

	$templFieldName = "username,password"
	$fieldValues = "test.user18,@User18Pass!"
	$secret = SecretCreate -secretName "Test User18 Secret" -templateName "Azure AD Account" -templateFieldNames $templFieldName  -folderId "52" -values $fieldValues

	#SynchronizeWithAD

	#$folderPerms = FolderPermissionGetAll
	#$folderPerms = FolderPermissionGetAllByFolderId -folderId 3
	#$folderPerm = FolderPermissionGet -id 17

	#$folderPerms = FolderPermissionGetByVals -userId 6 -folderId 16
	#$folderPerm = FolderPermissionCreate -folderAccessName "View" -secretAccessName "List" -userId 7 -folderId 16
		
	#$folders = FolderGetAll
	#$folders = FolderLookupAll 

	#$folder = FolderGet -id 9

	#$folder = FolderCreate -name "TEST2 Compliance and Legal" -parentFolderId 20
	#$folder = FolderCreate -name "Head of Compliance" -parentFolderId 27

	#$users = UserGetAll
	#$user = UserCreate -userName "Test.User3" -displayName "Test User3" -emailAddress "Test.User3@ceridian.com" -enabled $true -password "0neIdentity!"
	# $user = UserCreate -userName "DIMDIMSKY" `
	# 				-displayName "Dimsky, Dim" `
	# 				-emailAddress "Dim.Dimsky@oneidentity.demo" `
	# 				-password "@" `
	# 				-enabled 1

	#$oneUser = UserGet -id 3

	#$user = UserEnableDisable -id 6 -enabled $false
	
	#$groups = GroupGetAll 
	
	#$group = GroupGet -id 46

	#$allRoles = RoleGetAll

	#$role = RoleGet -id 3

	#UserUpdate -id 187 -groupIDs 46,47,48,49

	#UserUpdate -id 187 -groupIDs 46

	Disconnect

	Write-Information -MessageData "Time finished: $(Get-Date)" -InformationAction Continue


}catch{
	$message = $_
	Write-Warning "ERROR processing data: $message" 	
}