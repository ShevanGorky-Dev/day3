$parameter    = (Get-Content -Path C:\devops\repo\parameters.json  | convertFrom-json).parameters
$templatepath = 'C:\devops\repo\templates\arm'

# add owner subscription, login, az rest, create role groups, set rolegroups rights 


function AzureLogin
{
az login --only-show-errors --output none
az account set --subscription $($parameter.subscriptionidlz.value)
}

az rest --method post --url "/providers/Microsoft.Authorization/elevateAccess?api-version=2016-07-01"

function CreateManagementGroups($subscriptionlz,$Azureaccount)
{
$templateFile = "Bicep\Azure\scripts\managedgroups\main.bicep"
$parameters   = "@Bicep\Azure\scripts\managedgroups\main.parameters.json"

az deployment tenant create --name 'mgmt-groups' --location westeurope --template-file $templateFile --parameters parCustomerID=$($parameter.customerId.value) parCustomerFullName=$($parameter.customerFullName.value) authForNewMG=true configMGSettings=true
}


CreateManagementGroups -subscriptionlz $subscriptionlz -Azureaccount $Azureaccount


# az role assignment create --assignee-object-id 08c474bf-e8a9-41d0-b324-04fa23edbd24 --assignee-principal-type user --role "Owner" --scope "/"

function CreateResourceGroups
{
 create resourcegroups 

# resource groups pl connection
az deployment sub create `
--name "pl-con" `
--location $($parameter.rgLocation.value) `
--template-file ($templatepath +'\rg\pl-con\deploymentTemplate.json') `
--parameters rgLocation=$($parameter.rgLocation.value) customerid=$($parameter.customerId.value) `
--subscription $($parameter.subscriptionidcon.value)

# resource groups pl identity
az deployment sub create `
--name "pl-ide" `
--location $($parameter.rgLocation.value) `
--template-file ($templatepath +'\rg\pl-ide\deploymentTemplate.json') `
--parameters rgLocation=$($parameter.rgLocation.value) customerid=$($parameter.customerId.value) `
--subscription $($parameter.subscriptionidide.value)

# resource groups pl management
az deployment sub create `
--name "pl-man" `
--location $($parameter.rgLocation.value) `
--template-file ($templatepath +'\rg\pl-man\deploymentTemplate.json') `
--parameters rgLocation=$($parameter.rgLocation.value) customerid=$($parameter.customerId.value) `
--subscription $($parameter.subscriptionidman.value)

# resource groups lz customer
az deployment sub create `
--name "lz-cus" `
--location $($parameter.rgLocation.value) `
--template-file ($templatepath +'\rg\lz-cus\deploymentTemplate.json') `
--parameters rgLocation=$($parameter.rgLocation.value) customerid=$($parameter.customerId.value) `
--subscription $($parameter.subscriptionidlz.value)

}

### VNET

# VNET Platform connection
az account set --subscription $($parameter.subscriptionidcon.value)
az deployment group create `
--resource-group (($parameter.customerid.value) +'-pl-connectivity-net-prd-001') `
--name "pl-con" `
--template-file ($templatepath +'\vnet\pl-con\deploymentTemplate.json') `
--parameters rgLocation=$($parameter.rgLocation.value) customerid=$($parameter.customerId.value) addressprefix=$($parameter.addressprefix.value)

# VNET Platform identity
az account set --subscription $($parameter.subscriptionidide.value)
az deployment group create `
--resource-group (($parameter.customerid.value) +'-pl-identity-net-prd-001') `
--name "pl-ide" `
--template-file ($templatepath +'\vnet\pl-ide\deploymentTemplate.json') `
--parameters rgLocation=$($parameter.rgLocation.value) customerid=$($parameter.customerId.value) addressprefix=$($parameter.addressprefix.value)

# VNET Platform management
az account set --subscription $($parameter.subscriptionidman.value)
az deployment group create `
--resource-group (($parameter.customerid.value) +'-pl-management-net-prd-001') `
--name "pl-man" `
--template-file ($templatepath +'\vnet\pl-man\deploymentTemplate.json') `
--parameters rgLocation=$($parameter.rgLocation.value) customerid=$($parameter.customerId.value) addressprefix=$($parameter.addressprefix.value)

# VNET Landingzone customer
az account set --subscription $($parameter.subscriptionidlz.value)
az deployment group create `
--resource-group (($parameter.customerid.value) +'-lz-' +($parameter.customerid.value) +'-net-prd-001') `
--name "lz-cus" `
--template-file ($templatepath +'\vnet\lz-cus\deploymentTemplate.json') `
--parameters rgLocation=$($parameter.rgLocation.value) customerid=$($parameter.customerId.value) addressprefix=$($parameter.addressprefix.value)


#### NSG Subnet NEW
az deployment group create `
--resource-group (($parameter.customerid.value) +'-pl-connectivity-net-prd-001')`
--name "pl-con" `
--template-file  ($templatepath +'\nsg\pl-con\deploymentTemplate.json') `
--parameters  customerid=$($parameter.customerId.value)

az account set --subscription $($parameter.subscriptionidlz.value)
az deployment group create `
--resource-group (($parameter.customerid.value) +'-lz-' +($parameter.customerid.value) +'-net-prd-001') `
--name "lz-cus" `
--template-file ($templatepath +'\nsg\lz-cus\deploymentTemplate.json') `
--parameters  customerid=$($parameter.customerId.value)

function Create_IAM_groups {
    # 1. Create IAM groups
    $Owner = @(
        "IAM-UM-AZ-Root_Admin_Access-Owner-P"
    )
    
    $Contributor = @(
        ('IAM-UM-AZ-MG-Landingzone_' + ($parameter.customerid.value).ToUpper() + '_Prod' + '_Access-Contributor-P'),
        ('IAM-UM-AZ-MG-Platform_' + 'CON' + '_Access-Contributor-P'),
        ('IAM-UM-AZ-MG-Platform_' + 'IDE' + '_Access-Contributor-P'),
        ('IAM-UM-AZ-MG-Platform_' + 'MAN' + '_Access-Contributor-P')
    )
    
    $UAAdministrator = @(
        "IAM-UM-AZ-Root_Admin_Access-User_Access_Administrator-P"
    )
    
    function CreateRoleGroups {
        foreach ($obj in $Owner) {
            if (!(az ad group list --filter "displayname eq '$obj'" --only-show-errors | convertfrom-json)) {
                az ad group create --display-name $obj --mail-nickname $obj
            }
        }
        
        foreach ($obj in $Contributor) {
            if (!(az ad group list --filter "displayname eq '$obj'" --only-show-errors | convertfrom-json)) {
                az ad group create --display-name $obj --mail-nickname $obj
            }
        }
        
        foreach ($obj in $UAAdministrator) {
            if (!(az ad group list --filter "displayname eq '$obj'" --only-show-errors | convertfrom-json)) {
                az ad group create --display-name $obj --mail-nickname $obj
            }
        }
    }
    
    CreateRoleGroups
    Start-Sleep -Seconds 5
    
    # Root Roles
    az role assignment create --assignee-object-id (az ad group show --group $Owner[0] | ConvertFrom-Json).id --assignee-principal-type group --role "Owner" --scope "/"
    az role assignment create --assignee-object-id (az ad group show --group $UAAdministrator[0] | ConvertFrom-Json).id --assignee-principal-type group --role "User Access Administrator" --scope "/"
    
    # Management Group IDs
    $mg = (az account management-group list | ConvertFrom-Json).id
    $mgroot = $mg | Where-Object { $_ -notlike '*ebn*' }
    $mglz = $mg | Where-Object { $_ -like '*ebn-landingzones-ebn*' }
    
    # Set Contributor rights 
    az role assignment create --assignee-object-id (az ad group show --group $Contributor[0] | ConvertFrom-Json).id --assignee-principal-type group --role "Contributor" --scope ($mg | Where-Object { $_ -like $mglz })
    az role assignment create --assignee-object-id (az ad group show --group $Contributor[1] | ConvertFrom-Json).id --assignee-principal-type group --role "Contributor" --scope ($mg | Where-Object { $_ -like $mgcon })
    az role assignment create --assignee-object-id (az ad group show --group $Contributor[2] | ConvertFrom-Json).id --assignee-principal-type group --role "Contributor" --scope ($mg | Where-Object { $_ -like $mgide })
    az role assignment create --assignee-object-id (az ad group show --group $Contributor[3] | ConvertFrom-Json).id --assignee-principal-type group --role "Contributor" --scope ($mg | Where-Object { $_ -like $mgman })
}

# AZ Policy

az config set core.allow_broker false
az account clear
az login

az account set --subscription $($parameter.subscriptionidlz.value)

## Azure Policies from here! ##

$jsonpath = 'C:\devops\repo\templates\json\policy\definition'


function ParameterOptimize($parameterpath)
{
    $rules = (Invoke-WebRequest -Uri $parameterpath).Content -replace 'xxx', $($parameter.customerid.value)
    $rules = ConvertTo-Json $rules
    $rules = $rules -replace '\\r|\\n', ''
    Write-Output $rules
}

##### 1. Azure Policy RG Naming convention ######
function PolicyNamingRG {

    $name = ($($parameter.customerid.value) + '_policy_namingconvention_rg_v1.0')
    $policypath = ($mgroot + '/providers/Microsoft.Authorization/policyDefinitions/' + $name)
    #$policypath = ($mg[0] +'/providers/Microsoft.Authorization/policyDefinitions/' +$name)
    
    # 1. Naming convention RG (Werkend in Root) + change CustomID + JSON optimize (Params)
    az policy definition create --name $name `
    --rules ($jsonpath + '\namingconvention\rg\rules.json') `
    --params (ParameterOptimize -parameterpath ($jsonpath + '\namingconvention\rg\parameters.json')) `
    --management-group ($mgroot -replace '/providers/Microsoft.Management/managementGroups/', '') `
    --mode all
    
    # --management-group ((az account management-group list | convertFrom-Json).id[0]).replace('/providers/Microsoft.Management/managementGroups/','')
    
    # 2. Assign Namingconvention Policy 
    az policy assignment create `
    --display-name $name `
    --policy $policypath `
    --scope $mglz #$mg[4]
    
    # 3. Set Compliance Message VM Namingconvention
    az policy assignment non-compliance-message create `
    --message ('The resource group name you are using is not compliant following the ' + ($parameter.customerFullName.value).ToUpper()  + ' naming convention.' + ' Resource group naming convention starts with ' + ($parameter.customerid.value) + '-lz-' + ($parameter.customerid.value) + '-<3 letter>-<prd|tst|dev>-00x' + ' or ' + ($parameter.customerid.value) + '-<connectivity|platform|management>-<3 letter>-<prd|tst|dev>-00x') `
    --name ((az policy assignment list --scope $mglz | ConvertFrom-Json) | Where-Object { $_.DisplayName -eq $name }).Name `
    --scope $mglz #($mg[4]) 
}
#...
# Add other policy functions here
#...

# Call the function to create IAM groups
Create_IAM_groups
