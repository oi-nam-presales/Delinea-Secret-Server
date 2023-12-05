
$code = @"
public class SSLHandler
{
	public static System.Net.Security.RemoteCertificateValidationCallback GetSSLHandler()
	{

		return new System.Net.Security.RemoteCertificateValidationCallback((sender, certificate, chain, policyErrors) => { return true; });
	}
}
"@ 

class User
{
    [int]$id;
    [string]$userName;
    [string]$displayName;
    [string]$emailAddress;
    [bool]$enabled;
    [int]$domainId;
    [string[]]$roleIDs;
    [string[]]$groupIDs;
	[string]$password;
}

class Group
{
    [int]$id;
    [string]$name;
    [string]$domainName;
    [int]$domainId;
	[bool]$enabled;
}

class Role
{
    [int]$id;
    [string]$name;
    [bool]$enabled;
    [string[]]$groupIDs;
}

class Folder
{
    [int]$id;
    [string]$name;
    [int]$parentId;
	[string]$folderPath;
}

class FolderPermission
{
    [int]$id;
    [string]$folderAccessName;
    [string]$secretAccessName;
    [int]$folderId;
    [int]$groupId;
    [int]$userId;
    [string]$groupName;
    [string]$userName;
}

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

#==Connection values==========================
$script:_username = $null;
$script:_password = $null;
$script:_granttype = $null;
$script:_baseurl = $null;
$script:_logfolder = $null;
$script:_dodebug = $null;
$script:_headers = $null;
$script:_take = 200; #TODO - Change to 200
$script:_access_token = $null;
$script:_refresh_token = $null;
$script:_validate_ssl = $false

[string]$script:_logfile = "";

function SetParameters
{
    param(
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$Username,

        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$Password,

        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$GrantType,

        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$BaseURL,

        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$LogFolder,

        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$DoDebug,

		[parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$validateSSL = 'false'
    )

    $script:_username = $Username
    $script:_password = $Password
    $script:_granttype = $GrantType
    $script:_baseurl = $BaseURL
    $script:_logfolder = $LogFolder
    $script:_dodebug = $DoDebug
	
	#$script:_rmParams = @{}
    # if($validateSSL -eq $false){
    #     $script:_rmParams.SkipCertificateCheck  = $true
    # }

	[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

	#--> compile the class SSLHandler (above)
	if (-not ([System.Management.Automation.PSTypeName]'SSLHandler').Type)
	{
		Add-Type -TypeDefinition $code
	}

	#--> disable checks using new class
	[System.Net.ServicePointManager]::ServerCertificateValidationCallback = [SSLHandler]::GetSSLHandler()

	
    $script:_logFile =  Join-Path -Path $script:_logFolder -ChildPath "DelineaPSConnector_$((Get-Date).ToString("yyyy-MM-dd_HH-mm-ss-fff")).log"

	if($DoDebug -eq "Yes" -or $DoDebug -eq "True" -or $DoDebug -eq "1"){
		$script:_debug = $true
	}

	Write-Log -Message "SetParameters" -logfile $script:_logfile

	Login

	Write-Log -Message "Logged in" -logfile $script:_logfile
}

function Disconnect()
{
    $script:_username = $null
    $script:_password = $null
    $script:_granttype = $null
    $script:_baseurl = $null
    $script:_logfolder = $null
    $script:_dodebug = $null

	Logout
}

#======== USER ============================
function UserGetAll()
{

    $retUsers = @()
	Try
    {
		Write-Log -Message "UserGetAll" -logfile $script:_logfile
		        
        #Simple get
        $Uri = $script:_baseurl + "/api/v1/users?take=$script:_take" #&filter.includeInactive=true"
				
        $response = Invoke-RestMethod $Uri -Headers $script:_headers  #@script:_rmParams

		if(-not $response.success){

			Write-Log -Message "Error in UserGetAll: Unable to retrieve users" -logfile $script:_logfile -Level ERROR

			return $retUsers		
		}
	          
		#-->P.S. If first take is smaller than number of records - continue loading.
		if($response.Total -eq 0){
			Return $retUsers
		}

		$retUsers = PopulateUsers -users $response.records -isSmall $true

		if($response.pageCount -and $response.pageCount -gt 1){

			while($response.nextSkip -le $response.total)
			{
				$Uri = $script:_baseurl + "/api/v1/users?take=$script:_take&skip=$($response.nextSkip)" #&filter.includeInactive=true"

				$response = Invoke-RestMethod $Uri -Headers $script:_headers  #@script:_rmParams
				
				if(-not $response.success){

					Write-Log -Message "Error in UserGetAll: Unable to retrieve users - $($response.message)" -logfile $script:_logfile -Level ERROR

					return $retUsers		
				}

				if($response.records){
					$retUsers += PopulateUsers -users $response.records  -isSmall $true
				}
			} 
		}
				
		return $retUsers
	}
	catch{ 
		Write-Log -Message "UserGetAll - `n$_" -logfile $script:_logfile -Level ERROR
		throw "ERROR in UserGetAll - `n$_"
	}

	Write-Log -Message "Time: $(Get-Date)" -logfile $script:_logfile	

}

function UserGet
{
    param(
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [int]$id
    )
    
	$retUser = $null
	Try
    {
		Write-Log -Message "UserGet" -logfile $script:_logfile
		        
        #Simple get
        $Uri = $script:_baseurl + "/api/v1/users/$($id)" #?includeInactive=true"
				
        $response = Invoke-RestMethod $Uri -Headers $script:_headers  #@script:_rmParams
		
		if($response){
			$Groups = GetUserGroups -id $response.id
			$Roles = GetUserRoles -id $response.id

			$retUser = PopulateUser -User $response -Roles $Roles -Groups $Groups -isSmall $false
		}												
	}
	catch{ 
		Write-Log -Message "UserGet - `n$_" -logfile $script:_logfile -Level ERROR
		throw "ERROR in UserGet - `n$_"
	}

	Write-Log -Message "Time: $(Get-Date)" -logfile $script:_logfile	

	return $retUser
	
}

function UserEnableDisable
{
	param(
		[parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
		[ValidateNotNullOrEmpty()]
		[int]$id,

		[parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
		[ValidateNotNullOrEmpty()]
		[bool]$enabled
	)

	Write-Log -Message "UserEnableDisable" -logfile $script:_logfile

	$user = UserGet -id $id
	
	if(-not $user){
		Write-Log -Message "Unable to retrieve user with ID: $($id) - `n$_" -logfile $script:_logfile -Level ERROR
	}
    
    $Uri = $script:_baseurl + "/api/v1/users/$($id)?includeInactive=true"
    
	$userInfo = @{
		id = $id
		displayName = $user.displayName
		enabled = $enabled			
	}
	
	$body = $userInfo | ConvertTo-Json -Depth 2

	Try {

		Write-Log -Message "UserEnableDisable: User = $($user.displayName), Enabled = $($enabled)" -logfile $script:_logfile

        $response = Invoke-RestMethod -Method PUT -Uri $Uri -Headers $script:_headers -Body $body  #@script:_rmParams 
    }
    Catch {
        Write-Log -Message "UserEnableDisable: User = $($user.displayName), Enabled = $($enabled) - `n$_" -logfile $script:_logfile -Level ERROR
        throw "ERROR in UserEnableDisable: User = $($user.displayName), Enabled = $($enabled) `n[$($_)]"
    }

	$retUser = PopulateUser -user $response
	
	Return $retUser
}

function UserCreate
{
    param(
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [int]$id,

        [parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$userName,

        [parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$displayName,

        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$emailAddress,

        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [bool]$enabled,

        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [int]$domainId,
		
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [string[]]$roleIDs,

        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [string[]]$groupIDs,

		[parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [string]$password
    )

	Write-Log -Message "UserCreate" -logfile $script:_logfile

	if(-not $password){
		$password = "0neIdentity!"
	}
		        
    #Simple get
    $Uri = $script:_baseurl + "/api/v1/users"
    
	$userInfo = @{
		userName = $userName
		displayName = $displayName
		emailAddress = $emailAddress
		enabled = $enabled	
		password = $password
		domainId = -1
	}
	
	Try {

		Write-Log -Message "UserCreate: UserName = $($userName)" -logfile $script:_logfile

        $response = Invoke-RestMethod -Method POST -Uri $Uri -Headers $script:_headers -Body ($userInfo | ConvertTo-Json -Depth 4) #@script:_rmParams 
    }
    Catch {
        Write-Log -Message "UserCreate, UserName: $($UserName) - `n$_" -logfile $script:_logfile -Level ERROR
        throw "ERROR in UserCreate, UserName: $($UserName) `n[$($_)]"
    }

	if($roleIDs){
		Try {
			$Body = @{
				roleIds = $roleIDs
			}

			$Uri = $script:_baseurl + "/api/v1/users/$response.id/roles"

			$respRoles = Invoke-RestMethod -Method POST -Uri $Uri -Headers $script:_headers -Body ($Body |ConvertTo-Json -Depth 4)  #@script:_rmParams
		}
		Catch {
			Write-Log -Message "ERROR in UserCreate for UserName: $($userName) while adding roles - `n$_" -logfile $script:_logfile -Level ERROR
			throw "ERROR in UserCreate for UserName: $($userName) while adding roles - `n$_"
		}
	}

	if($groupIDs){
		Try {
			$Body = @{
				groupIds = $groupIDs
			}
			$Uri = $script:_baseurl + "/api/v1/users/$response.id/groups"

			$respGroups = Invoke-RestMethod -Method POST -Uri $Uri -Headers $script:_headers -Body ($Body | ConvertTo-Json -Depth 4)  #@script:_rmParams
		}
		Catch {
			Write-Log -Message "ERROR in UserCreate for UserName: $($userName) while adding groups - `n$_" -logfile $script:_logfile -Level ERROR
			throw "ERROR in UserCreate for UserName: $($userName) while adding groups - `n$_"
		}
	}

	$retUser = PopulateUser -user $response -Roles $roleIDs -Groups $groupIDs -isSmall $false

	Return $retUser

}

function UserUpdate
{
    param(
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [int]$id,

        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$userName,

        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$displayName,

        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$emailAddress,

        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [bool]$enabled,

        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [int]$domainId,

		[parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [string]$password,

        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [string[]]$roleIDs,

        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [string[]]$groupIDs
    )

  
	<#  
	  if ($PSBoundParameters.ContainsKey('userName')){$user.userName = [String]$PSBoundParameters['userName']}
	  if ($PSBoundParameters.ContainsKey('displayName')){$user.displayName = [String]$PSBoundParameters['displayName']}
	  if ($PSBoundParameters.ContainsKey('emailAddress')){$user.emailAddress = [String]$PSBoundParameters['emailAddress']}
	  if ($PSBoundParameters.ContainsKey('enabled')){$user.enabled = [Bool]$PSBoundParameters['enabled']}
	  if ($PSBoundParameters.ContainsKey('domainId')){$user.domainId = [Int]$PSBoundParameters['domainId']}
	  if ($PSBoundParameters.ContainsKey('password')){$user.emailAddress = [String]$PSBoundParameters['password']}
	  if ($PSBoundParameters.ContainsKey('roleIDs')){$user.roleIDs = [string[]]$PSBoundParameters['roleIDs']}
	  if ($PSBoundParameters.ContainsKey('groupIDs')){$user.groupIDs = [string[]]$PSBoundParameters['groupIDs']}
	#>

	#--> We don't have permissions to update user. For now only modify groups.

	if ($PSBoundParameters.ContainsKey('groupIDs')){ 
				
		UpdateUserGroups -id $id -groupIDs $([string[]]$PSBoundParameters['groupIDs'])
	}

}

function UserDelete
{
    param(
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [int]$id
    )
  
	throw "Method UserDelete is not implemented"
}

#P.S. Local methods =========================


#======== END USER ============================

#======== GROUP ============================
function GroupGetAll()
{

    $retGroups = @()
	Try
    {
		Write-Log -Message "GroupGetAll" -logfile $script:_logfile
		        
        #Simple get
        $Uri = $script:_baseurl + "/api/v1/groups/lookup?take=$script:_take" #&filter.includeInactive=true
				
        $response = Invoke-RestMethod $Uri -Headers $script:_headers  #@script:_rmParams

		if(-not $response.success){

			Write-Log -Message "Error in GroupGetAll: Unable to retrieve groups" -logfile $script:_logfile -Level ERROR

			return $retUsers		
		}
	      
		if($response.Total -eq 0){
			Return $retGroups
		}

		$retGroups = PopulateGroups -groups $response.records -isSmall $true

		if($response.pageCount -and $response.pageCount -gt 1){

			while($response.nextSkip -le $response.total)
			{
				$Uri = $script:_baseurl + "/api/v1/groups/lookup?take=$script:_take&skip=$($response.nextSkip)" #&filter.includeInactive=true

				$response = Invoke-RestMethod $Uri -Headers $script:_headers  #@script:_rmParams
				
				if(-not $response.success){

					Write-Log -Message "Error in GroupGetAll: Unable to retrieve users - $($response.message)" -logfile $script:_logfile -Level ERROR

					return $retGroups		
				}

				if($response.Total -ne 0){
					$retGroups += PopulateGroups -groups $response.records -isSmall $true
				}
			} 
		}
				
		return $retGroups
	}
	catch{ 
		Write-Log -Message "GroupGetAll - `n$_" -logfile $script:_logfile -Level ERROR
		throw "ERROR in GroupGetAll - `n$_"
	}

	Write-Log -Message "Time: $(Get-Date)" -logfile $script:_logfile	

}

function GroupGet
{
    param(
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [int]$id
    )
    
	$retGroup = $null
	Try
    {
		Write-Log -Message "GroupGet" -logfile $script:_logfile
		        
        #Simple get
        $Uri = $script:_baseurl + "/api/v1/groups/$($id)?includeInactive=true"
				
        $response = Invoke-RestMethod $Uri -Headers $script:_headers  #@script:_rmParams
		
		$retGroup = PopulateGroup -Group $response -isSmall $false				
						
		return $retGroup
	}
	catch{ 
		Write-Log -Message "GroupGet - `n$_" -logfile $script:_logfile -Level ERROR
		throw "ERROR in GroupGet - `n$_"
	}

	Write-Log -Message "Time: $(Get-Date)" -logfile $script:_logfile	

}

function GroupCreate
{
    param(
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [int]$id,

        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$name,

        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$domainName,

        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [int]$domainId
    )

    throw "Method GroupCreate is not implemented"

}

function GroupUpdate
{
    param(
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [int]$id,

        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$name,

        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$domainName,

        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [int]$domainId
    )

   throw "Method GroupUpdate is not implemented"

   <#
	  if ($PSBoundParameters.ContainsKey('name')){$group.name = [String]$PSBoundParameters['name']}
	  if ($PSBoundParameters.ContainsKey('domainName')){$group.domainName = [String]$PSBoundParameters['domainName']}
	  if ($PSBoundParameters.ContainsKey('domainId')){$group.domainId = [Int]$PSBoundParameters['domainId']}
   #>
}

function GroupDelete
{
    param(
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [int]$id
    )

    throw "Method GroupDelete is not implemented"
}

#P.S. Local methods =========================


#======== END GROUP =========================

#======== SECRET ============================
#$secret = SecretCreate -secretName "Test User8" -templateName "One Identity Secrets" -templateFieldName "One Identity Login" -folderId "62" -value "MyTestPassword!1"
function SecretCreate
{
    param(
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$secretName,

		[parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$templateName,

		[parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$templateFieldNames,

		[parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$folderId,

		[parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$values
    )   

	Write-Log -Message "SecretCreate" -logfile $script:_logfile
	
	$template = TemplateGetByName $templateName
	$arTempFieldNames = $templateFieldNames.Split(",")
	$arValues = $values.Split(",")

	if(-not $template){
		Write-Log -Message "SecretCreate - unable to find template $($templateName): `n$_" -logfile $script:_logfile -Level ERROR
		throw "ERROR in SecretCreate - unable to find template $($templateName)"
	}

	$folderManaged = FolderGetByVals -name "Managed" -parentFolderId $folderId
	
	if($folderManaged){
		$folderId = $folderManaged.id
	}

    $Uri = $script:_baseurl + "/api/v1/secrets"
    
	$secretInfo = @{
		name = $secretName
		secretTemplateId = $Template.id
		checkOutEnabled = $true
		enableInheritPermissions = $true
		enableInheritSecretPolicy = $true
		folderId = $folderId
		siteId = 1
		items = @()			
	}	
		
	for ($i = 0; $i -lt $arTempFieldNames.Length; $i++)
	{
		$secretInfo.items += @{
			fieldName = $arTempFieldNames[$i]
			itemValue = $arValues[$i]
		}
	}	

	$body = ($secretInfo | ConvertTo-Json -Depth 4)
	
	Try {
		
		Write-Log -Message "SecretCreate: UserName = $userName, TemplateName = $templateName, Template field name = $templateFieldName, Folder ID = $folderId, Value = $value" -logfile $script:_logfile
		
        Invoke-RestMethod -Method POST -Uri $Uri -Headers $script:_headers -Body $body  
    }
    Catch {
		$message = $_
        Write-Log -Message "SecretCreate: UserName = $userName, TemplateName = $templateName, Template field name = $templateFieldName, Folder ID = $folderId, Value = $value - `n$message" -logfile $script:_logfile -Level ERROR
        throw "ERROR in SecretCreate: UserName = $userName, TemplateName = $templateName, Template field name = $templateFieldName, Folder ID = $folderId, Value = $value - $($folderName) `n[$($message)]"
    }

}
#======== END SECRET ========================

#======== TEMPLATE ==========================
function TemplateGetByName
{
    param(
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$name
    )   

	$Template = $null
	$retTemplate = $null
	$respTemplates = $()
	Try
    {
		Write-Log -Message "TemplateGetByName" -logfile $script:_logfile
		        
        $Uri = $script:_baseurl + "/api/v1/secret-templates?take=$script:_take"

		if($name){
			$Uri = $Uri + "&filter.searchText=$($name)"
		}		

        $response = Invoke-RestMethod $Uri -Headers $script:_headers   #@script:_rmParams

		if(-not $response.success){

			Write-Log -Message "Error in TemplateGetByName: Unable to retrieve Template" -logfile $script:_logfile -Level ERROR

			return $retTemplates		
		}
	    
		if($response.Total -eq 0){
			Return $null
		}

		$respTemplates = $response.records
		
		if($response.pageCount -and $response.pageCount -gt 1){

			while($response.nextSkip -le $response.total)
			{
				$Uri = $script:_baseurl + "/api/v1/secret-templates?take=$script:_take&skip=$($response.nextSkip)"

				if($name){
					$Uri = $Uri + "&filter.searchText=$($name)"
				}
						
				$response = Invoke-RestMethod $Uri -Headers $script:_headers   #@script:_rmParams
				
				if(-not $response.success){

					Write-Log -Message "Error in TemplateGetByName: Unable to retrieve folders - $($response.message)" -logfile $script:_logfile -Level ERROR

					return $retFolders		
				}

				$respTemplates += $response.records
			} 
		}				
		
	}
	catch{ 
		Write-Log -Message "TemplateGetByName - `n$_" -logfile $script:_logfile -Level ERROR
		throw "ERROR in TemplateGetByName - `n$_"
	}

	
	foreach($respTemp in $respTemplates){
		if($respTemp.name -eq $name){
			 $retTemplate = $respTemp
			 break
		}
	}

	if($retTemplate) {
		$Template = TemplateGetById -id $retTemplate.id

		Return $Template
	}

	Write-Log -Message "Time: $(Get-Date)" -logfile $script:_logfile	

	return $null
}

function TemplateGetById
{
    param(
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [int]$id
    )
    
	$retTemplate = $null
	Try
    {
		Write-Log -Message "TemplateGetById" -logfile $script:_logfile
		        
        #Simple get
        $Uri = $script:_baseurl + "/api/v1/secret-templates/$($id)"
				
        $response = Invoke-RestMethod $Uri -Headers $script:_headers  #@script:_rmParams
		
		$retTemplate = PopulateTemplate -Template $response				
						
		return $retTemplate
	}
	catch{ 
		Write-Log -Message "TemplateGetById - `n$_" -logfile $script:_logfile -Level ERROR
		throw "ERROR in TemplateGetById - `n$_"
	}

	Write-Log -Message "Time: $(Get-Date)" -logfile $script:_logfile	
}

function PopulateTemplates
{
	param(
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        $templates
    )

	$retTemplates = @()

	foreach($template in $templates)
	{
		Write-Log -Message "Template - id=$($template.id), name=$($template.name)" -logfile $script:_logfile -Level Info
		
		$retTemplate = PopulateTemplate -Template $template
		            
		$retTemplates += $retTemplate				
	}

	return $retTemplates
}

function PopulateTemplate{
	param(
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        $Template
    )
	
	Write-Log -Message "PopulateTemplate: ID=$($Template.id), Name = $($Template.name)" -logfile $script:_logfile

	$templateInfo = @{
		id = $Template.id
		name = $Template.name	
		fields = @()	
	} 
		
	foreach($field in $Template.fields)
	{
		$field = @{
					name = $field.name
					id = $field.secretTemplateFieldId
				  }

				  $templateInfo.fields += $field
	}

	$templateObject = New-Object PSObject -Property $templateInfo
        
	return $templateObject
}
#======== END TENPLATE ============================

#======== FOLDER ============================
function FolderGetAll()
{

    $retFolders = @()
	Try
    {
		Write-Log -Message "FolderGetAll" -logfile $script:_logfile
				        
        #Simple get
        $Uri = $script:_baseurl + "/api/v1/folders?take=$script:_take" #&filter.includeInactive=true
				
        $response = Invoke-RestMethod $Uri -Headers $script:_headers   #@script:_rmParams

		if(-not $response.success){

			Write-Log -Message "Error in FolderGetAll: Unable to retrieve Folders" -logfile $script:_logfile -Level ERROR

			return $retFolders		
		}
	    
		if($response.Total -eq 0){
			Return $retFolders
		}
		
		$retFolders = PopulateFolders -folders $response.records

		if($response.pageCount -and $response.pageCount -gt 1){

			while($response.nextSkip -le $response.total)
			{
				$Uri = $script:_baseurl + "/api/v1/folders?take=$script:_take&skip=$($response.nextSkip)" #&filter.includeInactive=true

				$response = Invoke-RestMethod $Uri -Headers $script:_headers   #@script:_rmParams
				
				if(-not $response.success){

					Write-Log -Message "Error in FoldersGetAll: Unable to retrieve folders - $($response.message)" -logfile $script:_logfile -Level ERROR

					return $retFolders		
				}

				if($response.Total -ne 0){
					$retFolders += PopulateFolders -folders $response.records
				}				
			} 
		}				
		
	}
	catch{ 
		Write-Log -Message "FoldersGetAll - `n$_" -logfile $script:_logfile -Level ERROR
		throw "ERROR in FoldersGetAll - `n$_"
	}

	Write-Log -Message "Time: $(Get-Date)" -logfile $script:_logfile	

	return $retFolders
}

function FolderLookupAll()
{

    $retFolders = @()
	Try
    {
		Write-Log -Message "FolderLookupAll" -logfile $script:_logfile
				        
        #Simple get
        $Uri = $script:_baseurl + "/api/v1/folders/lookup?take=$script:_take" #&filter.includeInactive=true
				
        $response = Invoke-RestMethod $Uri -Headers $script:_headers   #@script:_rmParams

		if(-not $response.success){

			Write-Log -Message "Error in FolderGetAll: Unable to retrieve Folders" -logfile $script:_logfile -Level ERROR

			return $retFolders		
		}
	    
		if($response.Total -eq 0){
			Return $retFolders
		}
		
		foreach($floderLkp in $response.records){
			$retFolders += $floderLkp.id
		}
		
		if($response.pageCount -and $response.pageCount -gt 1){

			while($response.nextSkip -le $response.total)
			{
				$Uri = $script:_baseurl + "/api/v1/folders/lookup?take=$script:_take&skip=$($response.nextSkip)" #&filter.includeInactive=true

				$response = Invoke-RestMethod $Uri -Headers $script:_headers   #@script:_rmParams
				
				if(-not $response.success){

					Write-Log -Message "Error in FoldersGetAll: Unable to retrieve folders - $($response.message)" -logfile $script:_logfile -Level ERROR

					return $retFolders		
				}

				if($response.Total -ne 0){

					foreach($floderLkp in $response.records){
						$retFolders += $floderLkp.id 
					}
				}				
			} 
		}				
		
	}
	catch{ 
		Write-Log -Message "FolderLookupAll - `n$_" -logfile $script:_logfile -Level ERROR
		throw "ERROR in FolderLookupAll - `n$_"
	}

	Write-Log -Message "Time: $(Get-Date)" -logfile $script:_logfile	

	return $retFolders
}

function FolderGet
{
    param(
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [int]$id
    )
    
	$retFolder = $null
	Try
    {
		Write-Log -Message "FolderGet" -logfile $script:_logfile
		        
        #Simple get
        $Uri = $script:_baseurl + "/api/v1/folders/$($id)?includeInactive=true"
				
        $response = Invoke-RestMethod $Uri -Headers $script:_headers   #@script:_rmParams
				
		$retFolder = PopulateFolder -Folder $response				
						
		return $retFolder
	}
	catch{ 
		Write-Log -Message "FolderGet - `n$_" -logfile $script:_logfile -Level ERROR
		throw "ERROR in FolderGet - `n$_"
	}

	Write-Log -Message "Time: $(Get-Date)" -logfile $script:_logfile	

}

function FolderGetByVals
{
    param(
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$name,

		[parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [int]$parentFolderId
    )   

	$retFolders = $null
	
	Try
    {
		Write-Log -Message "FolderGetByVals" -logfile $script:_logfile
		        
        #Simple get
        $Uri = $script:_baseurl + "/api/v1/folders?take=$($script:_take)"

		if($name){
			$Uri = $Uri + "&filter.searchText=$($name)"
		}

		if($parentFolderId -ne 0){
			$Uri = $Uri + "&filter.parentFolderId=$($parentFolderId)"
		}

        $response = Invoke-RestMethod $Uri -Headers $script:_headers   #@script:_rmParams

		if(-not $response.success){

			Write-Log -Message "Error in FolderGetByVals: Unable to retrieve Folders" -logfile $script:_logfile -Level ERROR

			return $retFolders		
		}
	    
		if($response.Total -eq 0){
			Return $null
		}

		$retFolders = PopulateFolders -folders $response.records

		if($response.pageCount -and $response.pageCount -gt 1){

			while($response.nextSkip -le $response.total)
			{
				$Uri = $script:_baseurl + "/api/v1/folders?take=$script:_take&skip=$($response.nextSkip)"

				if($name){
					$Uri = $Uri + "&filter.searchText=$($name)"
				}
		
				if($parentFolderId -ne 0){
					$Uri = $Uri + "&filter.parentFolderId=$($parentFolderId)"
				}

				$response = Invoke-RestMethod $Uri -Headers $script:_headers   #@script:_rmParams
				
				if(-not $response.success){

					Write-Log -Message "Error in FolderGetByVals: Unable to retrieve folders - $($response.message)" -logfile $script:_logfile -Level ERROR

					return $retFolders		
				}

				$retFolders += PopulateFolders -folders $response.records
			} 
		}				
		
	}
	catch{ 
		Write-Log -Message "FolderGetByVals - `n$_" -logfile $script:_logfile -Level ERROR
		throw "ERROR in FolderGetByVals - `n$_"
	}

	
	foreach($retFolder in $retFolders){
		if($retFolder.name -eq $name -and $retFolder.parentId -eq $parentFolderId){
			return $retFolder
		}
	}

	Write-Log -Message "Time: $(Get-Date)" -logfile $script:_logfile	

	return $null

}

function FolderCreate
{
    param(
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [int]$id,

        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$name,

        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [int]$parentFolderId
    )

    Write-Log -Message "FolderCreate" -logfile $script:_logfile

	$existFolder = FolderGetByVals -name $name -parentFolderId $parentFolderId

	if($existFolder){
		return $existFolder
	}
		        
    #Simple get
    $Uri = $script:_baseurl + "/api/v1/folders"
    
	$folderInfo = @{
		folderName = $name
		folderTypeId = 1
	}

	$folderInfo.inheritPermissions = $false	
	$folderInfo.inheritSecretPolicy = $true

	if($parentFolderId -eq 0){		
		$folderInfo.parentFolderId = -1	
	}else{
		$folderInfo.parentFolderId = $parentFolderId		
	}
	
	$body = ($folderInfo | ConvertTo-Json -Depth 4)

	Try {
		#ParentFolderId = -1 - Department Folder, Not = -1 - Job Title Folder
		Write-Log -Message "FolderCreate: UserName = $($userName)" -logfile $script:_logfile
		
        $response = Invoke-RestMethod -Method POST -Uri $Uri -Headers $script:_headers -Body $body  # #@script:_rmParams
    }
    Catch {
        Write-Log -Message "FolderCreate, FolderName: $($folderName) - `n$_" -logfile $script:_logfile -Level ERROR
        throw "ERROR in FolderCreate, FolderName: $($folderName) `n[$($_)]"
    }

	$retFolder = PopulateFolder -Folder $response

	Return $retFolder
}

function FolderUpdate
{
    param(
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [int]$id,

        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$name,

        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [bool]$enabled,

        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [string[]]$groupIDs
    )

	throw "Method FolderUpdate is not implemented"
	<#

	  if ($PSBoundParameters.ContainsKey('name')){$role.name = [String]$PSBoundParameters['name']}
	  if ($PSBoundParameters.ContainsKey('enabled')){$role.enabled = [Bool]$PSBoundParameters['enabled']}
	  if ($PSBoundParameters.ContainsKey('groupIDs')){$role.groupIDs = [string[]]$PSBoundParameters['groupIDs']}
	#>
}

function FolderDelete
{
    param(
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [int]$id
    )
  throw "Method FolderDelete is not implemented"
}

#P.S. Local methods =========================


#======== END Folder ============================

#======== FOLDERPERMISSION ============================
function FolderPermissionGetAll()
{
	Write-Log -Message "FolderPermissionGetAll" -logfile $script:_logfile

	$retFolderPerms = @()
	$folderIDs = FolderLookupAll

	foreach($folderId in $folderIDs){
		$retFolderPerms += FolderPermissionGetAllByFolderId -folderId $folderId
	}

	Return $retFolderPerms
}

function FolderPermissionGetAllByFolderId()
{	
	param(
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$folderId
    )

    $retFolderPerms = @()
	Try
    {		
		Write-Log -Message "FolderPermissionGetAllByFolderId" -logfile $script:_logfile
				        
        #Simple get
        $Uri = $script:_baseurl + "/api/v1/folder-permissions?take=$script:_take"
				
		if($folderId){
			$Uri = $Uri + "&filter.folderId=" + $folderId
		}

        $response = Invoke-RestMethod $Uri -Headers $script:_headers   #@script:_rmParams

		if(-not $response.success){

			Write-Log -Message "Error in FolderPermissionGetAllByFolderId: Unable to retrieve Folder Permissions" -logfile $script:_logfile -Level ERROR
			return $retFolders		
		}
	          
		if(-not $response.records){
			Return $retFolderPerms
		}

		$retFolderPerms = PopulateFolderPermissions -folderPerms $response.records

		if($response.pageCount -and $response.pageCount -gt 1){

			while($response.nextSkip -le $response.total)
			{
				$Uri = $script:_baseurl + "/api/v1/folder-permissions?take=$script:_take&skip=$($response.nextSkip)"

				if($folderId){
					$Uri = $Uri + "&filter.folderId=" + $folderId
				}
		
				$response = Invoke-RestMethod $Uri -Headers $script:_headers   #@script:_rmParams
				
				if(-not $response.success){

					Write-Log -Message "Error in FolderPermissionGetAllByFolderId: Unable to retrieve folder permissions - $($response.message)" -logfile $script:_logfile -Level ERROR

					return $retFolderPerms		
				}

				if($response.records){
					$retFolderPerms += PopulateFolderPermissions -folderPerms $response.records
				}
			} 
		}				
		
	}
	catch{ 
		Write-Log -Message "FolderPermissionGetAllByFolderId - `n$_" -logfile $script:_logfile -Level ERROR
		throw "ERROR in FolderPermissionGetAllByFolderId - `n$_"
	}

	Write-Log -Message "Time: $(Get-Date)" -logfile $script:_logfile	

	return $retFolderPerms
}

function FolderPermissionGet
{
    param(
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [int]$id
    )   

	$retFolderPerm = $null
	Try
    {
		Write-Log -Message "FolderPermissionGet" -logfile $script:_logfile
		        
        #Simple get
        $Uri = $script:_baseurl + "/api/v1/folder-permissions/$($id)"
				
        $response = Invoke-RestMethod $Uri -Headers $script:_headers   #@script:_rmParams
				
		$retFolderPerm = PopulateFolderPermission -Folder $response				
						
		return $retFolderPerm
	}
	catch{ 
		Write-Log -Message "FolderPermissionGet - `n$_" -logfile $script:_logfile -Level ERROR
		throw "ERROR in FolderPermissionGet - `n$_"
	}

	Write-Log -Message "Time: $(Get-Date)" -logfile $script:_logfile	
}

function FolderPermissionGetByVals
{
    param(
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [int]$userId,

		[parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [int]$folderId,

		[parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [int]$groupId
    )   

	$retFolderPerms = $null
	
	Try
    {
		Write-Log -Message "FolderPermissionGetByVals" -logfile $script:_logfile
		        
        #Simple get
        $Uri = $script:_baseurl + "/api/v1/folder-permissions?take=$($script:_take)"

		if($userId -ne 0){
			$Uri = $Uri + "&filter.userId=$($userId)"
		}

		if($folderId -ne 0){
			$Uri = $Uri + "&filter.folderId=$($folderId)"
		}

		if($groupId -ne 0){
			$Uri = $Uri + "&filter.groupId=$($groupId)"
		}
		
        $response = Invoke-RestMethod $Uri -Headers $script:_headers   #@script:_rmParams

		if(-not $response.success){

			Write-Log -Message "Error in FolderPermissionGetByVals: Unable to retrieve Folder Permissions" -logfile $script:_logfile -Level ERROR

			return $retFolders		
		}

		if($response.Total -eq 0){
			Return $retFolderPerms
		}
		$retFolderPerms = PopulateFolderPermissions -folderPerms $response.records

		if($response.pageCount -and $response.pageCount -gt 1){

			while($response.nextSkip -le $response.total)
			{
				$Uri = $script:_baseurl + "/api/v1/folder-permissions?take=$script:_take&skip=$($response.nextSkip)"

				if($userId -ne 0){
					$Uri = $Uri + "&filter.userId=$($userId)"
				}
		
				if($folderId -ne 0){
					$Uri = $Uri + "&filter.folderId=$($folderId)"
				}
		
				if($groupId -ne 0){
					$Uri = $Uri + "&filter.groupId=$($groupId)"
				}

				$response = Invoke-RestMethod $Uri -Headers $script:_headers   #@script:_rmParams
				
				if(-not $response.success){

					Write-Log -Message "Error in FolderPermissionGetByVals: Unable to retrieve folder permissions - $($response.message)" -logfile $script:_logfile -Level ERROR

					return $retFolderPerms		
				}

				if($response.Total -ne 0){
					$retFolderPerms += PopulateFolderPermissions -folderPerms $response.records
				}
			} 
		}		


	}
	catch{ 
		Write-Log -Message "FolderPermissionGetByVals - `n$_" -logfile $script:_logfile -Level ERROR
		throw "ERROR in FolderPermissionGetByVals - `n$_"
	}

	Write-Log -Message "Time: $(Get-Date)" -logfile $script:_logfile	

	return $retFolderPerms
}

function FolderPermissionCreate
{
    param(
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [int]$id,

        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
		[ValidateSet('Owner','Edit','Add Secret', 'View')]
        [string]$folderAccessName,

        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
		[ValidateSet('Owner','Edit','List', 'View', 'None')]
        [string]$secretAccessName,

        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [int]$folderId,

        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [int]$groupId,

        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [int]$userId
    )

	Write-Log -Message "FolderPermissionCreate" -logfile $script:_logfile
		        
    #Simple get
    $Uri = $script:_baseurl + "/api/v1/folder-permissions"
    
	$folderInfo = @{
		breakInheritance = $true
		folderId = $folderId
		folderAccessRoleName = $folderAccessName
		secretAccessRoleName = $secretAccessName		
	}

	if($userId -ne 0){
		$folderInfo.userId = $userId		
	}

	if($groupId -ne 0){
		$folderInfo.groupId = $groupId		
	}
	
	Try {
		#ParentFolderId = -1 - Department Folder, Not = -1 - Job Title Folder
		Write-Log -Message "FolderPermissionCreate: folderId = $($folderId) folderAccessName = $($folderAccessName)" -logfile $script:_logfile

		$response = Invoke-RestMethod -Method POST -Uri $Uri -Headers $script:_headers -Body ($folderInfo | ConvertTo-Json -Depth 4)   #@script:_rmParams
    }
    Catch {
        Write-Log -Message "FolderPermissionCreate, folderId = $($folderId) - `n$_" -logfile $script:_logfile -Level ERROR
        throw "ERROR in FolderCreate, folderId = $($folderId) `n[$($_)]"
    }

	$retFolderPerm = PopulateFolderPermission -FolderPermisison $response

	Return $retFolderPerm
}

function FolderPermissionUpdate
{
    param(
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [int]$id,

        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$folderAccessName,

        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$secretAccessName,

        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [int]$folderId,

        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [int]$groupId,

        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [int]$userId,

        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$groupName,

        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$userName
    )

	throw "Method FolderDelete is not implemented"
}

function FolderPermissionDelete
{
    param(
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [int]$id
    )

	throw "Method FolderDelete is not implemented"
  
}

#P.S. Local methods =========================


#======== END FOLDERPERMISSION ============================

#======== ROLE ============================
function RoleGetAll()
{

    $retRoles = @()
	Try
    {
		Write-Log -Message "RoleGetAll" -logfile $script:_logfile
				        
        #Simple get
        $Uri = $script:_baseurl + "/api/v1/roles?take=$script:_take" #&filter.includeInactive=true
				
        $response = Invoke-RestMethod $Uri -Headers $script:_headers  #@script:_rmParams

		if(-not $response.success){

			Write-Log -Message "Error in RoleGetAll: Unable to retrieve groups" -logfile $script:_logfile -Level ERROR

			return $retRoles		
		}
	        
		if($response.Total -eq 0){
			Return $retRoles
		}
		$retRoles = PopulateRoles -roles $response.records

		if($response.pageCount -and $response.pageCount -gt 1){

			while($response.nextSkip -le $response.total)
			{
				$Uri = $script:_baseurl + "/api/v1/roles?take=$script:_take&skip=$($response.nextSkip)" #&filter.includeInactive=true

				$response = Invoke-RestMethod $Uri -Headers $script:_headers  #@script:_rmParams
				
				if(-not $response.success){

					Write-Log -Message "Error in RoleGetAll: Unable to retrieve users - $($response.message)" -logfile $script:_logfile -Level ERROR

					return $retGroups		
				}

				if($response.Total -ne 0){
					$retRoles += PopulateRoles -roles $response.records
				}
			} 
		}				
		
	}
	catch{ 
		Write-Log -Message "RoleGetAll - `n$_" -logfile $script:_logfile -Level ERROR
		throw "ERROR in RoleGetAll - `n$_"
	}

	Write-Log -Message "Time: $(Get-Date)" -logfile $script:_logfile	

	return $retRoles

}

function RoleGet
{
    param(
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [int]$id
    )
    
	$retRole = $null
	Try
    {
		Write-Log -Message "RoleGet" -logfile $script:_logfile
		        
        #Simple get
        $Uri = $script:_baseurl + "/api/v1/roles/$($id)?includeInactive=true"
				
        $response = Invoke-RestMethod $Uri -Headers $script:_headers  #@script:_rmParams
					          
		$Groups = GetRoleGroups -id $response.id
		
		$retRole = PopulateRole -Role $response -Groups $Groups
				
						
		return $retRole
	}
	catch{ 
		Write-Log -Message "UserGet - `n$_" -logfile $script:_logfile -Level ERROR
		throw "ERROR in UserGet - `n$_"
	}

	Write-Log -Message "Time: $(Get-Date)" -logfile $script:_logfile	

}

function RoleCreate
{
    param(
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [int]$id,

        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$name,

        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [bool]$enabled,

        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [string[]]$groupIDs
    )

    throw "Method RoleCreate is not implemented"

}

function RoleUpdate
{
    param(
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [int]$id,

        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$name,

        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [bool]$enabled,

        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [string[]]$groupIDs
    )

	throw "Method RoleUpdate is not implemented"
	<#

	  if ($PSBoundParameters.ContainsKey('name')){$role.name = [String]$PSBoundParameters['name']}
	  if ($PSBoundParameters.ContainsKey('enabled')){$role.enabled = [Bool]$PSBoundParameters['enabled']}
	  if ($PSBoundParameters.ContainsKey('groupIDs')){$role.groupIDs = [string[]]$PSBoundParameters['groupIDs']}
	#>
}

function RoleDelete
{
    param(
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [int]$id
    )
  throw "Method RoleDelete is not implemented"
}

#P.S. Local methods =========================


#======== END ROLE ============================

#============================================================================
#============================================================================
#======= START Local Functions ==============================================
#============================================================================
#============================================================================

function PopulateFolderPermissions
{
	param(
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        $folderPerms
    )

	$retFolderPerms = @()

	foreach($folderPerm in $folderPerms)
	{
		if($folderPerm.id -ne 1){
			Write-Log -Message "Folder - id=$($folderPerm.id), user =$($folderPerm.userName), permisison name = $($folderPerm.folderAccessRoleName) " -logfile $script:_logfile -Level Info
			
			$folderPermRet = PopulateFolderPermission -FolderPermisison $folderPerm
						
			$retFolderPerms += $folderPermRet				
		}
	}

	return $retFolderPerms
}
#============================================================================

function PopulateFolderPermission{
	param(
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        $FolderPermisison
    )
	
	Write-Log -Message "PopulateFolderPermission: ID=$($FolderPermisison.id), UserName = $($FolderPermisison.userName), Folder Permission Name = $($FolderPermisison.folderAccessRoleName)" -logfile $script:_logfile

	$folderPermInfo = @{
		id = $FolderPermisison.id
		folderId = $FolderPermisison.folderId		
		groupId = $FolderPermisison.groupId
		userId = $FolderPermisison.userId
		groupName = $FolderPermisison.groupName
		userName = $FolderPermisison.userName
		folderAccessName = $FolderPermisison.folderAccessRoleName
		secretAccessName = $FolderPermisison.secretAccessRoleName
	}
		
	$folderPermObject = New-Object PSObject -Property $folderPermInfo
        
	return $folderPermObject
}

#=======================================================================================

function PopulateFolders
{
	param(
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        $folders
    )

	$retFolders = @()

	foreach($folder in $folders)
	{
		Write-Log -Message "Folder - id=$($folder.id), name=$($folder.name)" -logfile $script:_logfile -Level Info
		
		$folderRet = PopulateFolder -Folder $folder
		            
		$retFolders += $folderRet				
	}

	return $retFolders
}
#============================================================================

function PopulateFolder{
	param(
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        $Folder
    )
	
	Write-Log -Message "PopulateFolder: ID=$($Folder.id), FolderName = $($Folder.name), ParentId = $($Folder.parentId), folderPath = $($Folder.folderPath)" -logfile $script:_logfile

	$folderInfo = @{
		id = $Folder.id
		name = $Folder.folderName		
		parentId = $Folder.parentFolderId
		folderPath = $Folder.folderPath
	}
		
	$folderObject = New-Object PSObject -Property $folderInfo
        
	return $folderObject
}

#============================================================================
function GetRoleGroups
{
    param(
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [int]$id
    )
    
	$retGroups = @() #New-Object System.Collections.ArrayList
	Try
    {
		Write-Log -Message "GetRoleGroups" -logfile $script:_logfile
		        
        #Simple get
        $Uri = $script:_baseurl + "/api/v1/roles/$($id)/groups?includeInactive=true&take=$script:_take"
				
        $response = Invoke-RestMethod $Uri -Headers $script:_headers  #@script:_rmParams

		if(-not $response.success){

			Write-Log -Message "Error in GetRoleGroups: Unable to retrieve user groups: $($response.message)" -logfile $script:_logfile -Level ERROR

			return $retGroups		
		}
	          
		foreach($group in $response.records)
		{
			#$retGroups.Add($group.groupId) | Out-Null
			$retGroups += $group.groupId
		}
	}
	catch{ 
		Write-Log -Message "GetUserGroups - `n$_" -logfile $script:_logfile -Level ERROR
		throw "ERROR in GetUserGroups - `n$_"
	}

	Write-Log -Message "Time: $(Get-Date)" -logfile $script:_logfile	

	return $retGroups
	
}

#======================================================================================
function PopulateRoles 
{
	param(
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        $roles
    )

	$retRoles = @()

	foreach($role in $roles)
	{
		Write-Log -Message "Role - id=$($role.id), name=$($role.name)" -logfile $script:_logfile -Level Info
		
		$roleRet = PopulateRole -Role $role -Groups @()
		            
		$retRoles += $roleRet				
	}

	return $retRoles
}

#=======================================================================================

function PopulateRole{
	param(
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        $Role,

		[parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [string[]]$Groups = @()
    )
	
	Write-Log -Message "PopulateGroup: ID=$($Group.id), GroupName = $($Group.name)" -logfile $script:_logfile

	$roleInfo = @{
		id = $Role.id
		name = $Role.name		
		enabled = $Role.enabled
	}
	
	if($Groups){
		$roleInfo.groupIDs = $Groups
	}else{
		$roleInfo.groupIDs = @()
	}

	$roleObject = New-Object PSObject -Property $roleInfo
        
	return $roleObject
}

#==========================================================================================
#==========================================================================================
#==========================================================================================

function PopulateGroups 
{
	param(
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        $groups,

		[parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        $isSmall = $true
    )

	$retGroups = @()

	foreach($group in $groups)
	{
		if($isSmall){
			Write-Log -Message "Group - id=$($group.id), name=$($group.value)" -logfile $script:_logfile -Level Info		
		}else{
			Write-Log -Message "Group - id=$($group.id), name=$($group.name)" -logfile $script:_logfile -Level Info
		}

		$groupRet = PopulateGroup -Group $group -isSmall $isSmall
		            
		$retGroups += $groupRet				
	}

	return $retGroups
}

#=======================================================================================

function PopulateGroup{
	param(
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        $Group,
				
		[parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        $isSmall = $true
    )
			
	if($isSmall){

		Write-Log -Message "PopulateGroup small: ID=$($Group.id), Username = $($Group.value)" -logfile $script:_logfile
				
		$userInfo = @{
			id = $Group.id
			name = $Group.value
			domainName = $null
			domainId = $null
			enabled = $true			
		}
	}else{

		Write-Log -Message "PopulateGroup: ID=$($Group.id), GroupName = $($Group.name)" -logfile $script:_logfile

		$userInfo = @{
			id = $Group.id
			name = $Group.name
			domainName = $Group.domainName
			domainId = $Group.domainId	
			enabled = $Group.enabled
		}
	}
	
	$userObject = New-Object PSObject -Property $userInfo
        
	return $userObject
}

#==========================================================================================
function GetUserRoles
{
    param(
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [int]$id
    )
    
	$retRoles = New-Object Collections.Generic.List[string]
	Try
    {
		Write-Log -Message "GetUserRoles" -logfile $script:_logfile
		        
        #Simple get
        $Uri = $script:_baseurl + "/api/v1/users/$($id)/roles-assigned?includeInactive=true&take=$script:_take"
				
        $response = Invoke-RestMethod $Uri -Headers $script:_headers  #@script:_rmParams

		if(-not $response.success){

			Write-Log -Message "Error in GetUserRoles: Unable to retrieve user roles: $($response.message)" -logfile $script:_logfile -Level ERROR

			return $retGroups		
		}
	          
		foreach($role in $response.records)
		{
			$retRoles.Add($role.roleId) | Out-Null
		}
				
						
		return $retRoles.ToArray()
	}
	catch{ 
		Write-Log -Message "GetUserRoles - `n$_" -logfile $script:_logfile -Level ERROR
		throw "ERROR in GetUserRoles - `n$_"
	}

	Write-Log -Message "Time: $(Get-Date)" -logfile $script:_logfile	
	
}
#===================================================================================

function UpdateUserGroups 
{
    param(
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [int]$id,

		[parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [string[]]$groupIDs = @()
    )
   
	
	Try {
		$Body = @{
			groupIds = $groupIDs
		} | ConvertTo-Json

		$Uri = $script:_baseurl + "/api/v1/users/$id/groups"

		$headers = $script:_headers
		$headers."Content-Type"="application/json"

		$respGroups = Invoke-RestMethod -Method PUT -Uri $Uri -Headers $headers -Body $Body  #@script:_rmParams

		if(-not $respGroups.success -eq $true){
			Write-Log -Message "ERROR in UpdateUserGroups for User id = $($id) while updating groups - `n$respGroups.message" -logfile $script:_logfile -Level ERROR
			return 
		}

	}
	Catch {

		$messg = $_

		Write-Log -Message "ERROR in UpdateUserGroups for User id = $($id) while updating groups - `n$messg" -logfile $script:_logfile -Level ERROR
		throw "ERROR in UpdateUserGroups for User id = $($id) while updating groups - `n$messg"
	}
}

#===================================================================================
function GetUserGroups
{
    param(
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [int]$id
    )
    
	$retGroups = New-Object Collections.Generic.List[string]
	Try
    {
		Write-Log -Message "GetUserGroups" -logfile $script:_logfile
		        
        #Simple get
        $Uri = $script:_baseurl + "/api/v1/users/$($id)/groups?includeInactive=true&take=$script:_take"
				
        $response = Invoke-RestMethod $Uri -Headers $script:_headers  #@script:_rmParams

		if(-not $response.success){

			Write-Log -Message "Error in GetUserGroups: Unable to retrieve user groups: $($response.message)" -logfile $script:_logfile -Level ERROR

			return $retGroups		
		}
	          
		foreach($group in $response.records)
		{
			$retGroups.Add($group.groupId) | Out-Null
		}
				
						
		return $retGroups.ToArray()
	}
	catch{ 
		Write-Log -Message "GetUserGroups - `n$_" -logfile $script:_logfile -Level ERROR
		throw "ERROR in GetUserGroups - `n$_"
	}

	Write-Log -Message "Time: $(Get-Date)" -logfile $script:_logfile	
	
}
#=====================================================================================

function PopulateUsers 
{
	param(
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        $users,
				
		[parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        $isSmall = $true
    )

	$retUsers = @()

	foreach($user in $users)
	{
		Write-Log -Message "User - id=$($user.id), name=$($user.userName)" -logfile $script:_logfile -Level Info
		
		$userRet = PopulateUser -User $user -Roles $null -Groups $null -isSmall $isSmall
		            
		$retUsers += $userRet				
	}

	return $retUsers
}
#===============================================================================
function PopulateUser{
	param(
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        $User,

		[parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [string[]]$Groups = @(),

		[parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [string[]]$Roles = @(),

		[parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        $isSmall = $true
    )

	$userInfo = @{
		id = $User.Id
		userName = $User.userName
		displayName = $User.displayName
		emailAddress = $User.emailAddress
		enabled = $User.enabled
		domainId = $User.domainId
		roleIDs = @()
		groupIDs = @()
		password = ""
	}
	
			
	if(-not $isSmall){
		
		Write-Log -Message "PopulateUser: ID=$($User.id), Username = $($User.userName)" -logfile $script:_logfile
		
		if($Roles){
			$userInfo.roleIDs = $Roles
		}else{
			$userInfo.roleIDs = @()
		}
		
		if($Groups){
			$userInfo.groupIDs = $Groups
		}else{
			$userInfo.groupIDs = @()
		}
	}
	
	$userObject = New-Object PSObject -Property $userInfo
        
	return $userObject
}

#================================================================
Function SynchronizeWithAD{
	
	Try
    {
		Write-Log -Message "GetUserGroups" -logfile $script:_logfile
		        
        #Simple get
        $Uri = $script:_baseurl + "/api/v1/directory-services/synchronization-now" #active-directory/synchronize" https://dc01.oneidentity.demo/api/v1/directory-services/synchronization-now
				
        $response = Invoke-RestMethod -Method POST -Uri $Uri -Headers $script:_headers  

		if($response -ne $true){

			Write-Log -Message "Error in SynchronizeWithAD: $($response.message)" -logfile $script:_logfile -Level ERROR					
		}	          
		
	}
	catch{ 
		Write-Log -Message "SynchronizeWithAD - `n$_" -logfile $script:_logfile -Level ERROR
		throw "ERROR in SynchronizeWithAD - `n$_"
	}	
}

#================================================================

function Login()
{
	try
	{
		$site = $script:_baseurl
		
						
		$authTokenArgs = @{
							username = "$script:_username"
							password = "$script:_password"
							grant_type = "$script:_granttype"							
						} 

		$headers = @{"Accept"= "application/json"; "Content-Type"="application/x-www-form-urlencoded"} 
		$url = "$site/oauth2/token"
		$ret = Invoke-RestMethod $url -Method Post -Body $authTokenArgs -Headers $headers   #@script:_rmParams

		$script:_headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"		
		$script:_headers.Add("Authorization", "Bearer $($ret.access_token)")
		$script:_headers += @{"Content-Type" = "application/json"}

		$script:_access_token = $ret.access_token;
		$script:_refresh_token = $ret.refresh_token;


	}
	catch [System.Net.WebException]
	{		
		Write-Log -Message "Error logging in - `n[$($_)]" -logfile $script:_logfile -Level ERROR
		throw "Error logging in - `n[$($_)]"
	}
}

#================================================================

function Logout()
{
	try
	{
		$site = $script:_baseurl
    
		$token = $script:_authToken

		$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
		$headers.Add("Authorization", "Bearer $token")

		$expireToken = Invoke-RestMethod "$site/api/v1/oauth-expiration" -Headers $headers -Method Post  #@script:_rmParams
	}catch {}

}

#================================================================

Function Write-Log {
   
    Param(
		[Parameter(Mandatory=$True)]
		[string]$Message,

		[Parameter(Mandatory=$False)]
		[string]$logfile,

		[Parameter(Mandatory=$False)]
		[ValidateSet("INFO","WARN","ERROR","FATAL","DEBUG")]
		[String]$Level = "INFO"
    )

	if($script:_debug -eq $False ){
		return
	}

    $Stamp = (Get-Date).toString("yyyy/MM/dd HH:mm:ss")
    $Line = "$Stamp - $Level - $Message"
	
	if($Level -eq "ERROR"){
		$Line = "!!!==================`n" + $Line + "`n!!!=================="
	}

	#TODO - Uncomment
    If($logfile) {

		$mutexName = "PSMutex"

		$mutex = New-Object 'Threading.Mutex' $false, $mutexName

		# Grab the mutex. Will block until this process has it.
		$mutex.WaitOne() | Out-Null

		try {
			Add-Content $logfile -Value $Line 
		}
		finally {
			$mutex.ReleaseMutex() 
		}
        
    }

	Write-Information -MessageData $Line -InformationAction Continue  
}


#======= END Local Functions ================================================

Export-ModuleMember -Function *
