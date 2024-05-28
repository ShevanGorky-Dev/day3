$parameter    = (Get-Content -Path C:\MS_Demo\Day3\repo\parameters.json  | convertFrom-json).parameters
$templatepath = 'C:\MS_Demo\Day3\repo\templates\arm'

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


#
function Create_IAM_groups {
    # 1. Create IAM groups
    $Owner = @(
    "IAM-UM-AZ-Root_Admin_Access-Owner-P"
    )
    
    
    $Contributor = @(
    ('IAM-UM-AZ-MG-Landingzone_' +($($parameter.customerid.value).ToUpper() +'_Prod'+'_Access-Contributor-P')),
    ('IAM-UM-AZ-MG-Platform_' +'CON' +'_Access-Contributor-P'),
    ('IAM-UM-AZ-MG-Platform_' +'IDE' +'_Access-Contributor-P'),
    ('IAM-UM-AZ-MG-Platform_' +'MAN' +'_Access-Contributor-P')
    
    )
    
    
    $UAAdministrator = @(
    "IAM-UM-AZ-Root_Admin_Access-User_Access_Administrator-P"
    )
    
    function CreateRoleGroups {
    
    foreach ($obj in $owner){
    if (!(az ad group list --filter "displayname eq '$($obj)' " --only-show-errors | convertfrom-json)) 
        {az ad group create --display-name $obj --mail-nickname $obj} 
    }
    
    foreach ($obj in $Contributor){
    if (!(az ad group list --filter "displayname eq '$($obj)' " --only-show-errors | convertfrom-json)) 
        {az ad group create --display-name $obj --mail-nickname $obj}
    }
    
    foreach ($obj in $UAAdministrator){
    if (!(az ad group list --filter "displayname eq '$($obj)' " --only-show-errors| convertfrom-json)) 
        {az ad group create --display-name $obj --mail-nickname $obj}
    }
    
    }
    
    CreateRoleGroups
    sleep 5
    
    # Root Roles
    az role assignment create --assignee-object-id (az ad group show --group $Owner | ConvertFrom-Json).id --assignee-principal-type group --role "Owner" --scope "/"
    az role assignment create --assignee-object-id (az ad group show --group $UAAdministrator | ConvertFrom-Json).id --assignee-principal-type group --role "User Access Administrator" --scope "/"
    
    # 
    
    $mg    = (az account management-group list | convertFrom-Json).id
    $mglz  = ('*' +($parameter.customerid.value) +'-landingzones-' +($parameter.customerid.value) +'-prod' +'*')
    $mgcon = ('*' +($parameter.customerid.value) +'-platform-connectivity' +'*')
    $mgide = ('*' +($parameter.customerid.value) +'-platform-identity' +'*')
    $mgman = ('*' +($parameter.customerid.value) +'-platform-management' +'*')
    
    # Set Contributor rights 
    az role assignment create --assignee-object-id (az ad group show --group $Contributor[0] | ConvertFrom-Json).id --assignee-principal-type group --role "Contributor" --scope ($mg | Where-Object {$_ -like $mglz})
    az role assignment create --assignee-object-id (az ad group show --group $Contributor[1] | ConvertFrom-Json).id --assignee-principal-type group --role "Contributor" --scope ($mg | Where-Object {$_ -like $mgcon})
    az role assignment create --assignee-object-id (az ad group show --group $Contributor[2] | ConvertFrom-Json).id --assignee-principal-type group --role "Contributor" --scope ($mg | Where-Object {$_ -like $mgide})
    az role assignment create --assignee-object-id (az ad group show --group $Contributor[3] | ConvertFrom-Json).id --assignee-principal-type group --role "Contributor" --scope ($mg | Where-Object {$_ -like $mgman})
    
    }
    

#az role assignment delete --assignee adm_estekelenburg@qizini.com --role "Owner" --scope "/"

# AZ Policy

        az config set core.allow_broker=false
        az account clear
        az login


        az account set --subscription $($parameter.subscriptionidlz.value)


        ## Azure Policies from here! ##
        ## $templatepath = 'C:\devops\repo\templates\json\policy\definition'
        $jsonpath = 'C:\devops\repo\templates\json\policy\definition'
        ## $jsonpath = 'https://raw.githubusercontent.com/pinkelephant-nl/pnk_azure_avd_automation_public/main/templates/json/policy/definition'

        $mg = (az account management-group list | convertFrom-Json).id
        $mgroot   = $mg | where-object {$_ -notlike '*ebn*'}
        $mglz     = $mg | where-object {$_ -like '*ebn-landingzones-ebn'}


function ParameterOptimize($parameterpath)
{
$rules = ((Invoke-WebRequest -Uri $parameterpath).content).replace('xxx',$($parameter.customerid.value))
$rules = convertTo-Json $rules
$rules = $rules.replace('\r','').Replace('\n','')
write-output $rules
}

##### 1. Azure Policy RG Naming convention ######
function PolicyNamingRG{

    $name = (($parameter.customerid.value) +'_policy_namingconvention_rg_v1.0')
    $policypath = ($mgroot +'/providers/Microsoft.Authorization/policyDefinitions/' +$name)
    #$policypath = ($mg[0] +'/providers/Microsoft.Authorization/policyDefinitions/' +$name)
    
    # 1. Naming convention RG (Werkend in Root) + change CustomID + JSON optimize (Params)
    az policy definition create --name $name `
    --rules ($jsonpath +'\namingconvention\rg\rules.json') `
    --params (ParameterOptimize -parameterpath ($jsonpath +'\namingconvention\rg\parameters.json')) `
    --management-group ($mgroot).replace('/providers/Microsoft.Management/managementGroups/','') `
    --mode all
    
    # --management-group ((az account management-group list | convertFrom-Json).id[0]).replace('/providers/Microsoft.Management/managementGroups/','')
    
    # 2. Assign Namingconvention Policy 
    az policy assignment create `
    --display-name $name `
    --policy $policypath `
    --scope $mglz #$mg[4]
    
    # 3. Set Compliance Message VM Namingconvention
    az policy assignment non-compliance-message create `
    --message ('The resource group name you are using is not compliant following the ' +($parameter.customerFullName.value).ToUpper()  +' naming convention.' +' Resource group naming convention starts with ' +($parameter.customerid.value) +'-lz-' +($parameter.customerid.value) +'-<3 letter>-<prd|tst|dev>-00x' +' or ' +($parameter.customerid.value) +'-<connectivity|platform|management>-<3 letter>-<prd|tst|dev>-00x') `
    --name ((az policy assignment list --scope $mglz | convertFrom-Json) | Where-Object {$_.displayName -eq $name}).name `
    --scope $mglz #($mg[4]) 
    
    }

    
##### 2. Azure Policy VM Naming convention ######
function PolicyNamingVM{

$name = (($parameter.customerid.value) +'_policy_namingconvention_vm_v1.0')
$policypath = ($mgroot +'/providers/Microsoft.Authorization/policyDefinitions/' +$name)
$exclusions = 
                    ('/subscriptions/' +($parameter.subscriptionidlz.value) +'/resourceGroups/' +($parameter.customerid.value) +'-lz-' +$parameter.customerid.value +'-aib-dev-001', 
                    '/subscriptions/' +($parameter.subscriptionidlz.value) +'/resourceGroups/' +($parameter.customerid.value) +'-lz-' +$parameter.customerid.value +'-aib-prd-001')
 

# 1. Naming convention VM (Werkend in Root) + change CustomID + JSON optimize (Params)
az policy definition create --name $name `
--rules ($jsonpath +'\namingconvention\vm\rules.json') `
--params (ParameterOptimize -parameterpath ($jsonpath +'\namingconvention\vm\parameters.json')) `
--management-group ($mgroot).replace('/providers/Microsoft.Management/managementGroups/','') `
--mode all

# --management-group ((az account management-group list | convertFrom-Json).id[0]).replace('/providers/Microsoft.Management/managementGroups/','')

# 2. Assign Namingconvention Policy 
az policy assignment create `
--display-name $name `
--policy $policypath `
--not-scopes $exclusions `
--scope $mglz #$mg[4]

# 3. Set Compliance Message VM Namingconvention
az policy assignment non-compliance-message create `
--message ('The VM name does not meet the ' +($parameter.customerFullName.value).ToUpper()  +' naming convention.' +' Use the naming convention ' +($parameter.customerid.value) +'-az(x)-adc-[number]' +', ' +($parameter.customerid.value) +'-az(x)-azc-[number]' +', ' +($parameter.customerid.value) +'-az(x)-mgt-[number]' +', ' +($parameter.customerid.value)+'-az(x)-app-[number]' +', ' +($parameter.customerid.value) +'-az(x)-dbs-[number]' +' and ' +($parameter.customerid.value) +'-az(x)-avd-[number]. ' +'Where  x = P|T|D (Prod|Test|Dev)') `
--name ((az policy assignment list --scope ($mglz) | convertFrom-Json) | Where-Object {$_.displayName -eq $name}).name `
--scope ($mglz) #$mg[4]
#(az policy definition list --management-group ($mg[0]).replace('/providers/Microsoft.Management/managementGroups/',''))
}

##### 3. Azure Policy Datacenter Location(s) ######
function PolicyLocation{

    $name = (($parameter.customerid.value) +'_policy_location_v1.0')
    $policypath = ($mgroot +'/providers/Microsoft.Authorization/policyDefinitions/' +$name)
     
    # 1. Location (Placed in Management Root) + change CustomID + JSON optimize (Params)
    az policy definition create --name $name `
    --rules ($jsonpath +'\location\rules.json') `
    --params ($jsonpath +'\location\parameters.json') `
    --management-group ($mgroot).replace('/providers/Microsoft.Management/managementGroups/','')
    
    # 2. Assign location policy 
    az policy assignment create `
    --display-name $name `
    --policy $policypath `
    --scope $mglz
    
    # 3. Set Compliance Message location(s)
    az policy assignment non-compliance-message create `
    --message ('You are trying to configure a resource group in a location which is not allowed to use. +($parameter.customerFullName.value).ToUpper() Azure locations are West Europe (Default) or North Europe).') `
    --name ((az policy assignment list --scope ($mglz) | convertFrom-Json) | Where-Object {$_.displayName -eq $name}).name `
    --scope ($mglz) 
    
    }

    function PolicyPIP{

        $name = (($parameter.customerid.value) +'_policy_network_pip_not_allowed_v1.0')
        $policypath = ($mgroot +'/providers/Microsoft.Authorization/policyDefinitions/' +$name)
        $exclusions = (
                         '/subscriptions/' +($parameter.subscriptionidlz.value) +'/resourceGroups/' +($parameter.customerid.value) +'-lz-' +($parameter.customerid.value) +'-net-prd-001',
                         '/subscriptions/' +($parameter.subscriptionidlz.value) +'/resourceGroups/' +($parameter.customerid.value) +'-lz-' +($parameter.customerid.value) +'-aib-prd-001',
                         '/subscriptions/' +($parameter.subscriptionidlz.value) +'/resourceGroups/' +($parameter.customerid.value) +'-lz-' +($parameter.customerid.value) +'-aib-dev-001',
                         '/subscriptions/' +($parameter.subscriptionidcon.value) +'/resourceGroups/' +($parameter.customerid.value) +'-pl-connectivity' +'-net-prd-001',
                         '/subscriptions/' +($parameter.subscriptionidman.value) +'/resourceGroups/' +($parameter.customerid.value) +'-pl-management' +'-net-prd-001'
        )
        
#                       '/subscriptions/' +($parameter.subscriptionidide.value) +'/resourceGroups/' +($parameter.customerid.value) +'-pl-identity' +'-net-prd-001',

        # 1. PIP (Placed in Management Root) + change CustomID + JSON optimize (Params)
        az policy definition create --name $name `
        --rules ($jsonpath +'\network\pip\rules.json') `
        --management-group ($mgroot).replace('/providers/Microsoft.Management/managementGroups/','')
        
        # 2. Assign location policy 
        az policy assignment create `
        --display-name $name `
        --policy $policypath `
        --not-scopes $exclusions `
        --scope $mgroot
        
        # 3. Set Compliance Message location(s)
        az policy assignment non-compliance-message create `
        --message ('By policy it is not allowed to enroll public IP addresses in the ' +($($parameter.customerFullName.value).ToUpper()) +' environment (Network resourcegroups are excluded from this policy)') `
        --name ((az policy assignment list --scope ($mgroot) | convertFrom-Json) | Where-Object {$_.displayName -eq $name}).name `
        --scope ($mgroot) 
       
        }

       '(By policy it is not allowed to enroll public IP addresses in the +($parameter.customerFullName.value).ToUpper() environment (Network resourcegroups are excluded from this policy))'
##### 1. Azure Migrate Project

az deployment group create `
--resource-group (($parameter.customerid.value) +'-lz-' +($parameter.customerid.value) +'-bck-prd-001')`
--name "migrate" `
--template-uri ($templatepath +'\migrate\deploymentTemplate.json') `
--parameters location=$($parameter.rgLocation.value) customerid=$($parameter.customerid.value)


### VPN Gateway TEST


az account set --subscription $($parameter.subscriptionidcon.value)

az deployment group create `
--resource-group (($parameter.customerid.value) +'-pl-connectivity-net-prd-001')`
--name "vpn-gateway" `
--template-uri ($templatepath +'\vpn\gateway\con\deploymentTemplate.json') `
--parameters location=$($parameter.rgLocation.value) customerid=$($parameter.customerid.value) customerFullName=$($parameter.customerFullName.value) subscriptionidcon=$($parameter.subscriptionidcon.value)

# 2. Create Connection EBN

az network local-gateway create `
--resource-group ($parameter.customerid.value +'-pl-connectivity-net-prd-001') `
--name ($parameter.customerid.value +'-lng-pl-con-azure_' +'utr_' +'primary' +'-prd-001') `
--gateway-ip-address '20.4.240.70' `
--local-address-prefixes '172.10.0.0/24' `
--output none

az network vpn-connection create `
--resource-group ($parameter.customerid.value.ToLower() +'-pl-connectivity-net-prd-001') `
--name ($parameter.customerid.value.ToLower() +'-con-pl-con-azure_' +$parameter.customerid.value.ToLower() +'_main_' +'primary' +'-prd-001') `
--vnet-gateway1 ($parameter.customerid.value.ToLower() +'-vgw-' +'gw1az_' +$parameter.customerFullName.value +'_main' +'-prd' +'-westeu-001') `
--local-gateway2 ($parameter.customerid.value +'-lng-pl-con-azure_' +'utr_' +'primary' +'-prd-001') `
--shared-key (ConvertTo-SecureString '6M0YMRudTLsqmcPVSJCg' -AsPlainText -Force) `
--use-policy-based-traffic-selectors true `
--output none




