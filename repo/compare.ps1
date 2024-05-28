$parameter    = (Get-Content -Path C:\MS_Demo\Day3\repo\parameters.json | ConvertFrom-Json).parameters
$templatepath = 'C:\MS_Demo\Day3\repo\templates\arm'

# Function to perform Azure login
function AzureLogin {
    az login --only-show-errors --output none
    az account set --subscription $($parameter.subscriptionidlz.value)
}

# Elevated access (if needed)
az rest --method post --url "/providers/Microsoft.Authorization/elevateAccess?api-version=2016-07-01"

# Function to create management groups
function CreateManagementGroups($subscriptionlz, $Azureaccount) {
    $templateFile = "$templatepath\managedgroups\main.bicep"
    $parameters   = "@$templatepath\managedgroups\main.parameters.json"

    az deployment tenant create --name 'mgmt-groups' --location westeurope --template-file $templateFile --parameters parCustomerID=$($parameter.customerId.value) parCustomerFullName=$($parameter.customerFullName.value) authForNewMG=true configMGSettings=true
}

CreateManagementGroups -subscriptionlz $subscriptionlz -Azureaccount $Azureaccount

# Function to create resource groups
function CreateResourceGroups {
    # Resource groups pl connection
    az deployment sub create `
    --name "pl-con" `
    --location $($parameter.rgLocation.value) `
    --template-file ($templatepath +'\rg\pl-con\deploymentTemplate.json') `
    --parameters rgLocation=$($parameter.rgLocation.value) customerid=$($parameter.customerId.value) `
    --subscription $($parameter.subscriptionidcon.value)

    # Resource groups pl identity
    az deployment sub create `
    --name "pl-ide" `
    --location $($parameter.rgLocation.value) `
    --template-file ($templatepath +'\rg\pl-ide\deploymentTemplate.json') `
    --parameters rgLocation=$($parameter.rgLocation.value) customerid=$($parameter.customerId.value) `
    --subscription $($parameter.subscriptionidide.value)

    # Resource groups pl management
    az deployment sub create `
    --name "pl-man" `
    --location $($parameter.rgLocation.value) `
    --template-file ($templatepath +'\rg\pl-man\deploymentTemplate.json') `
    --parameters rgLocation=$($parameter.rgLocation.value) customerid=$($parameter.customerId.value) `
    --subscription $($parameter.subscriptionidman.value)

    # Resource groups lz customer
    az deployment sub create `
    --name "lz-cus" `
    --location $($parameter.rgLocation.value) `
    --template-file ($templatepath +'\rg\lz-cus\deploymentTemplate.json') `
    --parameters rgLocation=$($parameter.rgLocation.value) customerid=$($parameter.customerId.value) `
    --subscription $($parameter.subscriptionidlz.value)
}

# VNETs
function CreateVNETs {
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
}

# Call the function to create resource groups and VNETs
CreateResourceGroups
CreateVNETs

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

