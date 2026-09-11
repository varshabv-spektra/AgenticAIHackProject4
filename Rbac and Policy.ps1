# =====================================================================================
# Generate-RbacAndPolicy.ps1
# Updated to use the Az PowerShell module (AzureRM is retired / no longer available).
# =====================================================================================

# ---- Sign in and select subscription -------------------------------------------------
# If interactive browser sign-in fails with a "window handle" error (common on RDP/lab
# VMs and Server Core), use device code sign-in instead:
#   Connect-AzAccount -UseDeviceAuthentication
Connect-AzAccount -UseDeviceAuthentication
Get-AzSubscription
$subscriptionID = "1cd29b4c-c7dc-4c95-9adf-e519c39dd697"
Select-AzSubscription -Subscription $subscriptionID
# If Select-AzSubscription is unavailable in your Az version, use instead:
# Set-AzContext -SubscriptionId $subscriptionID

$rbacName = "Spektra Custom RBAC"
<# Name you provide in $rbacName will be written in Rbac name field as shown below
{
  "Name": "Custom RBAC Name",
  "Id": null,
#>

# ---- Ensure all output folders exist before anything writes to them ------------------
# (Start-Transcript and Out-File do NOT create missing folders - they throw
# DirectoryNotFoundException if the path doesn't already exist.)
Function createDirectory {
    New-Item -ItemType Directory -Path C:\Rbac-Policy\Policy\rawdata\ -Force | Out-Null
    New-Item -ItemType Directory -Path C:\Rbac-Policy\Rbac\ -Force | Out-Null
} createDirectory
<#----------------------------------------------------------------------------#>

# Below Command will write the console output in a text file
Start-Transcript -Path C:\Rbac-Policy\Policy\rawdata\rawdata.txt -Append


Function RGsOneByOne {
    # Below two commands are there to get the RGs. One is added as comment and one executable.
    # If you want Rbac for particular RGs then add TagName and TagValue for those particular RGs.

    $RGs = "lab-vm", "contosofoundry-demo-rg"
    # $RGs = Get-AzResourceGroup

    # $TagName = "Enter Tag name of RG here"
    # $TagValue = "Enter Tag value of RG here"
    # $RGs = Get-AzResourceGroup -Tag @{ "$TagName"=$TagValue }

    foreach ($RG in $RGs) {

        $RGName = $RG
        Write-Host "======================================================="
        Write-Host "Resource Group Name :" $RGName
        Write-Host "======================================================="
        $resources = Get-AzResource -ResourceGroupName $RGName

        $exactResources = @()
        $resourceTypesForRbac = @()
        $resourceTypesForPolicy = @()
        $exactResources1 = @()
        $resourceTypesForRbac1 = @()
        $resourceTypesForPolicy1 = @()

        # Default actions required in an RBAC file
        $resourceTypesForRbac += '"Microsoft.Authorization/*/read",'
        $resourceTypesForRbac += '"Microsoft.Resources/deployments/*",'
        $resourceTypesForRbac += '"Microsoft.Resources/subscriptions/resourceGroups/read",'


        # Find unique set of ResourceType
        foreach ($resource in $resources) {
            $resource.ResourceType
            $resourceTypesForRbac += '"' + $resource.ResourceType + "/*" + '",'
            $resourceTypesForPolicy += $resource.ResourceType + "/*"
            $exactResources += '"' + $resource.ResourceType + '",'
        }

        $resourceTypesForPolicy1 += $resourceTypesForPolicy | Select-Object -Unique | Sort-Object

        $resourceTypesForRbac1 += $resourceTypesForRbac | Select-Object -Unique | Sort-Object
        if ($resourceTypesForRbac1.Length -gt 0) { $resourceTypesForRbac1[$resourceTypesForRbac1.Length - 1] = ($resourceTypesForRbac1[$resourceTypesForRbac1.Length - 1] -replace ",$", "") }

        $exactResources1 += $exactResources | Select-Object -Unique | Sort-Object
        if ($exactResources1.Length -gt 0) { $exactResources1[$exactResources1.Length - 1] = ($exactResources1[$exactResources1.Length - 1] -replace ",$", "") }

        <#-----------------------------------------------------------------------------------------------------------------------------------------#>

        # Storage Account
        $storageAccounts = Get-AzStorageAccount -ResourceGroupName $RGName -ErrorAction SilentlyContinue
        if ($storageAccounts) {
            $storageSKUArray = @()
            $storageSKUArray1 = @()
            foreach ($storageAccount in $storageAccounts) {
                $storageSKUArray += '"' + $storageAccount.Sku.Name + '",'
            }

            $storageSKUArray1 += $storageSKUArray | Select-Object -Unique | Sort-Object
            if ($storageSKUArray1.Length -gt 0) { $storageSKUArray1[$storageSKUArray1.Length - 1] = ($storageSKUArray1[$storageSKUArray1.Length - 1] -replace ",$", "") }
        }
        <#-----------------------------------------------------------------------------------------------------------------------------------------#>

        # Virtual Machine
        $VMs = Get-AzVM -ResourceGroupName $RGName -ErrorAction SilentlyContinue
        if ($VMs) {
            $vmSizeArray = @()
            $vmImagePublisherArray = @()
            $vmImageOfferArray = @()
            $vmImageSkuArray = @()
            $vmSizeArray1 = @()
            $vmImagePublisherArray1 = @()
            $vmImageOfferArray1 = @()
            $vmImageSkuArray1 = @()
            foreach ($VM in $VMs) {
                $vmSizeArray += '"' + $VM.HardwareProfile.VmSize + '",'
                $vmImagePublisherArray += '"' + $VM.StorageProfile.ImageReference.Publisher + '",'
                $vmImageOfferArray += '"' + $VM.StorageProfile.ImageReference.Offer + '",'
                $vmImageSkuArray += '"' + $VM.StorageProfile.ImageReference.Sku + '",'
            }

            $vmSizeArray1 += $vmSizeArray | Select-Object -Unique | Sort-Object
            if ($vmSizeArray1.Length -gt 0) { $vmSizeArray1[$vmSizeArray1.Length - 1] = ($vmSizeArray1[$vmSizeArray1.Length - 1] -replace ",$", "") }

            $vmImagePublisherArray1 += $vmImagePublisherArray | Select-Object -Unique | Sort-Object
            if ($vmImagePublisherArray1.Length -gt 0) { $vmImagePublisherArray1[$vmImagePublisherArray1.Length - 1] = ($vmImagePublisherArray1[$vmImagePublisherArray1.Length - 1] -replace ",$", "") }

            $vmImageOfferArray1 += $vmImageOfferArray | Select-Object -Unique | Sort-Object
            if ($vmImageOfferArray1.Length -gt 0) { $vmImageOfferArray1[$vmImageOfferArray1.Length - 1] = ($vmImageOfferArray1[$vmImageOfferArray1.Length - 1] -replace ",$", "") }

            $vmImageSkuArray1 += $vmImageSkuArray | Select-Object -Unique | Sort-Object
            if ($vmImageSkuArray1.Length -gt 0) { $vmImageSkuArray1[$vmImageSkuArray1.Length - 1] = ($vmImageSkuArray1[$vmImageSkuArray1.Length - 1] -replace ",$", "") }
        }
        <#-----------------------------------------------------------------------------------------------------------------------------------------#>

        # SQL Server/DB
        $sqlDatabases = $null
        $sqlServers = Get-AzSqlServer -ResourceGroupName $RGName -ErrorAction SilentlyContinue
        if ($sqlServers) {
            $sqlServerVersionsArray = @()
            $sqlDBEditionArray = @()
            $sqlDBObjectiveIdArray = @()
            $sqlDBServiceObjectiveNameArray = @()
            $sqlServerVersionsArray1 = @()
            $sqlDBEditionArray1 = @()
            $sqlDBObjectiveIdArray1 = @()
            $sqlDBServiceObjectiveNameArray1 = @()
            foreach ($sqlServer in $sqlServers) {
                $sqlServerName = $sqlServer.ServerName
                $sqlServerVersionsArray += '"' + $sqlServer.ServerVersion + '",'
                $sqlDatabases = Get-AzSqlDatabase -ResourceGroupName $RGName -ServerName $sqlServerName -ErrorAction SilentlyContinue
                if ($sqlDatabases) {
                    foreach ($sqlDatabase in $sqlDatabases) {
                        $sqlDBEditionArray += '"' + $sqlDatabase.Edition + '",'
                        $sqlDBObjectiveIdArray += '"' + $sqlDatabase.CurrentServiceObjectiveId + '",'
                        $sqlDBServiceObjectiveNameArray += '"' + $sqlDatabase.CurrentServiceObjectiveName + '",'
                    }
                }
            }

            $sqlServerVersionsArray1 += $sqlServerVersionsArray | Select-Object -Unique | Sort-Object
            if ($sqlServerVersionsArray1.Length -gt 0) { $sqlServerVersionsArray1[$sqlServerVersionsArray1.Length - 1] = ($sqlServerVersionsArray1[$sqlServerVersionsArray1.Length - 1] -replace ",$", "") }

            $sqlDBEditionArray1 += $sqlDBEditionArray | Select-Object -Unique | Sort-Object
            if ($sqlDBEditionArray1.Length -gt 0) { $sqlDBEditionArray1[$sqlDBEditionArray1.Length - 1] = ($sqlDBEditionArray1[$sqlDBEditionArray1.Length - 1] -replace ",$", "") }

            $sqlDBObjectiveIdArray1 += $sqlDBObjectiveIdArray | Select-Object -Unique | Sort-Object
            if ($sqlDBObjectiveIdArray1.Length -gt 0) { $sqlDBObjectiveIdArray1[$sqlDBObjectiveIdArray1.Length - 1] = ($sqlDBObjectiveIdArray1[$sqlDBObjectiveIdArray1.Length - 1] -replace ",$", "") }

            $sqlDBServiceObjectiveNameArray1 += $sqlDBServiceObjectiveNameArray | Select-Object -Unique | Sort-Object
            if ($sqlDBServiceObjectiveNameArray1.Length -gt 0) { $sqlDBServiceObjectiveNameArray1[$sqlDBServiceObjectiveNameArray1.Length - 1] = ($sqlDBServiceObjectiveNameArray1[$sqlDBServiceObjectiveNameArray1.Length - 1] -replace ",$", "") }
        }

        <#-----------------------------------------------------------------------------------------------------------------------------------------#>

        # App Service Plan
        $appServicePlans = Get-AzAppServicePlan -ResourceGroupName $RGName -ErrorAction SilentlyContinue
        if ($appServicePlans) {
            $appServicePlanSKUNameArray = @()
            $appServicePlanSKUTierArray = @()
            $appServicePlanSKUNameArray1 = @()
            $appServicePlanSKUTierArray1 = @()
            foreach ($appServicePlan in $appServicePlans) {
                $appServicePlanSKUNameArray += '"' + $appServicePlan.Sku.Name + '",'
                $appServicePlanSKUTierArray += '"' + $appServicePlan.Sku.Tier + '",'
            }

            $appServicePlanSKUNameArray1 += $appServicePlanSKUNameArray | Select-Object -Unique | Sort-Object
            if ($appServicePlanSKUNameArray1.Length -gt 0) { $appServicePlanSKUNameArray1[$appServicePlanSKUNameArray1.Length - 1] = ($appServicePlanSKUNameArray1[$appServicePlanSKUNameArray1.Length - 1] -replace ",$", "") }

            $appServicePlanSKUTierArray1 += $appServicePlanSKUTierArray | Select-Object -Unique | Sort-Object
            if ($appServicePlanSKUTierArray1.Length -gt 0) { $appServicePlanSKUTierArray1[$appServicePlanSKUTierArray1.Length - 1] = ($appServicePlanSKUTierArray1[$appServicePlanSKUTierArray1.Length - 1] -replace ",$", "") }
        }
        <#-----------------------------------------------------------------------------------------------------------------------------------------#>

        # VM Scale Set
        $vmScaleSets = Get-AzVmss -ResourceGroupName $RGName -ErrorAction SilentlyContinue
        if ($vmScaleSets) {
            $vmScaleSetSKUNameArray = @()
            $vmScaleSetSKUTierArray = @()
            $vmScaleSetSKUNameArray1 = @()
            $vmScaleSetSKUTierArray1 = @()
            foreach ($vmScaleSet in $vmScaleSets) {
                $vmScaleSetSKUNameArray += '"' + $vmScaleSet.Sku.Name + '",'
                $vmScaleSetSKUTierArray += '"' + $vmScaleSet.Sku.Tier + '",'
            }

            $vmScaleSetSKUNameArray1 += $vmScaleSetSKUNameArray | Select-Object -Unique | Sort-Object
            if ($vmScaleSetSKUNameArray1.Length -gt 0) { $vmScaleSetSKUNameArray1[$vmScaleSetSKUNameArray1.Length - 1] = ($vmScaleSetSKUNameArray1[$vmScaleSetSKUNameArray1.Length - 1] -replace ",$", "") }

            $vmScaleSetSKUTierArray1 += $vmScaleSetSKUTierArray | Select-Object -Unique | Sort-Object
            if ($vmScaleSetSKUTierArray1.Length -gt 0) { $vmScaleSetSKUTierArray1[$vmScaleSetSKUTierArray1.Length - 1] = ($vmScaleSetSKUTierArray1[$vmScaleSetSKUTierArray1.Length - 1] -replace ",$", "") }
        }

        <#-----------------------------------------------------------------------------------------------------------------------------------------#>

        # Disk
        $disks = Get-AzDisk -ResourceGroupName $RGName -ErrorAction SilentlyContinue
        if ($disks) {
            $diskSKUNameArray = @()
            $diskSKUTierArray = @()
            $diskSKUNameArray1 = @()
            $diskSKUTierArray1 = @()
            foreach ($disk in $disks) {
                $diskSKUNameArray += '"' + $disk.Sku.Name + '",'
                $diskSKUTierArray += '"' + $disk.Sku.Tier + '",'
            }

            $diskSKUNameArray1 += $diskSKUNameArray | Select-Object -Unique | Sort-Object
            if ($diskSKUNameArray1.Length -gt 0) { $diskSKUNameArray1[$diskSKUNameArray1.Length - 1] = ($diskSKUNameArray1[$diskSKUNameArray1.Length - 1] -replace ",$", "") }

            $diskSKUTierArray1 += $diskSKUTierArray | Select-Object -Unique | Sort-Object
            if ($diskSKUTierArray1.Length -gt 0) { $diskSKUTierArray1[$diskSKUTierArray1.Length - 1] = ($diskSKUTierArray1[$diskSKUTierArray1.Length - 1] -replace ",$", "") }
        }

        <#-----------------------------------------------------------------------------------------------------------------------------------------#>

        # Load Balancer
        $lbs = Get-AzLoadBalancer -ResourceGroupName $RGName -ErrorAction SilentlyContinue
        if ($lbs) {
            $lbSKUNameArray = @()
            $lbSKUNameArray1 = @()
            foreach ($lb in $lbs) {
                $lbSKUNameArray += '"' + $lb.Sku.Name + '",'
            }

            $lbSKUNameArray1 += $lbSKUNameArray | Select-Object -Unique | Sort-Object
            if ($lbSKUNameArray1.Length -gt 0) { $lbSKUNameArray1[$lbSKUNameArray1.Length - 1] = ($lbSKUNameArray1[$lbSKUNameArray1.Length - 1] -replace ",$", "") }
        }

        <#-----------------------------------------------------------------------------------------------------------------------------------------#>

        # Application Gateway
        $appGateways = Get-AzApplicationGateway -ResourceGroupName $RGName -ErrorAction SilentlyContinue
        if ($appGateways) {
            $appGatewaySKUTierArray = @()
            $appGatewaySKUTierArray1 = @()
            foreach ($appGateway in $appGateways) {
                $appGatewaySKUTierArray += '"' + $appGateway.Sku.Tier + '",'
            }

            $appGatewaySKUTierArray1 += $appGatewaySKUTierArray | Select-Object -Unique | Sort-Object
            if ($appGatewaySKUTierArray1.Length -gt 0) { $appGatewaySKUTierArray1[$appGatewaySKUTierArray1.Length - 1] = ($appGatewaySKUTierArray1[$appGatewaySKUTierArray1.Length - 1] -replace ",$", "") }
        }

        <#-----------------------------------------------------------------------------------------------------------------------------------------#>

        # Express Route Circuit
        $expressRoutes = Get-AzExpressRouteCircuit -ResourceGroupName $RGName -ErrorAction SilentlyContinue
        if ($expressRoutes) {
            $expressRoutesSKUTierArray = @()
            $expressRoutesSKUTierArray1 = @()
            foreach ($expressRoute in $expressRoutes) {
                $expressRoutesSKUTierArray += '"' + $expressRoute.Sku.Tier + '",'
            }

            $expressRoutesSKUTierArray1 += $expressRoutesSKUTierArray | Select-Object -Unique | Sort-Object
            if ($expressRoutesSKUTierArray1.Length -gt 0) { $expressRoutesSKUTierArray1[$expressRoutesSKUTierArray1.Length - 1] = ($expressRoutesSKUTierArray1[$expressRoutesSKUTierArray1.Length - 1] -replace ",$", "") }
        }

        <#-----------------------------------------------------------------------------------------------------------------------------------------#>

        # Cognitive Services
        $cognitiveServiceAccounts = Get-AzCognitiveServicesAccount -ResourceGroupName $RGName -ErrorAction SilentlyContinue
        if ($cognitiveServiceAccounts) {
            $cognativeServicesSKUArray = @()
            $cognativeServicesSKUArray1 = @()
            foreach ($cognitiveServiceAccount in $cognitiveServiceAccounts) {
                $cognativeServicesSKUArray += '"' + $cognitiveServiceAccount.Sku.Name + '",'
            }

            $cognativeServicesSKUArray1 += $cognativeServicesSKUArray | Select-Object -Unique | Sort-Object
            if ($cognativeServicesSKUArray1.Length -gt 0) { $cognativeServicesSKUArray1[$cognativeServicesSKUArray1.Length - 1] = ($cognativeServicesSKUArray1[$cognativeServicesSKUArray1.Length - 1] -replace ",$", "") }
        }

        <#-----------------------------------------------------------------------------------------------------------------------------------------#>

        # Container Registry
        $containerRegistries = Get-AzContainerRegistry -ResourceGroupName $RGName -ErrorAction SilentlyContinue
        if ($containerRegistries) {
            $containerRegistrySKUArray = @()
            $containerRegistrySKUArray1 = @()
            foreach ($containerRegistry in $containerRegistries) {
                $containerRegistrySKUArray += '"' + $containerRegistry.SkuName + '",'
            }

            $containerRegistrySKUArray1 += $containerRegistrySKUArray | Select-Object -Unique | Sort-Object
            if ($containerRegistrySKUArray1.Length -gt 0) { $containerRegistrySKUArray1[$containerRegistrySKUArray1.Length - 1] = ($containerRegistrySKUArray1[$containerRegistrySKUArray1.Length - 1] -replace ",$", "") }
        }

        <#-----------------------------------------------------------------------------------------------------------------------------------------#>

        # Key Vaults
        $keyVaults = Get-AzKeyVault -ResourceGroupName $RGName -ErrorAction SilentlyContinue
        if ($keyVaults) {
            $keyVaultSKUArray = @()
            $keyVaultSKUArray1 = @()
            foreach ($keyVault in $keyVaults) {
                $currentKeyVault = Get-AzKeyVault -VaultName $keyVault.VaultName
                $keyVaultSKUArray += '"' + $currentKeyVault.Sku + '",'
            }

            $keyVaultSKUArray1 += $keyVaultSKUArray | Select-Object -Unique | Sort-Object
            if ($keyVaultSKUArray1.Length -gt 0) { $keyVaultSKUArray1[$keyVaultSKUArray1.Length - 1] = ($keyVaultSKUArray1[$keyVaultSKUArray1.Length - 1] -replace ",$", "") }
        }

        <#-----------------------------------------------------------------------------------------------------------------------------------------#>

        # Event Hub
        $eventHubs = Get-AzEventHubNamespace -ResourceGroupName $RGName -ErrorAction SilentlyContinue
        if ($eventHubs) {
            $eventHubSKUArray = @()
            $eventHubSKUArray1 = @()
            foreach ($eventHub in $eventHubs) {
                $eventHubSKUArray += '"' + $eventHub.Sku.Name + '",'
            }

            $eventHubSKUArray1 += $eventHubSKUArray | Select-Object -Unique | Sort-Object
            if ($eventHubSKUArray1.Length -gt 0) { $eventHubSKUArray1[$eventHubSKUArray1.Length - 1] = ($eventHubSKUArray1[$eventHubSKUArray1.Length - 1] -replace ",$", "") }
        }

        <#-----------------------------------------------------------------------------------------------------------------------------------------#>
        Function policy {
            Param(
                [switch]$Passthru
            )
            if ($Passthru) {
                '{
 "if": {
    "anyOf": [
     {
        "not": {
          "anyOf": ['
                for ($i = 0; $i -le $resourceTypesForPolicy1.Length - 1; $i++) {
                    '                    {
                    "field": "type",
                    "like": "' + $resourceTypesForPolicy1[$i] + '"
                    },'
                }
                '                    {
                    "field": "type",
                    "in": [' + "$exactResources1" + ']
                    }
                ]
            }
         },'

                <#-----------------------------------------------------------------------------------------------------------------------------------------#>
                if ($disks) {
                    '          {
          "allof": [
            {
              "field": "type",
              "equals": "Microsoft.Compute/disks"
            },
            {
              "not": {
                "field": "Microsoft.Compute/disks/Sku.Tier",
                "in": [' + "$diskSKUTierArray1" + ']
                }
              }
            ]
          },'
                }

                <#-----------------------------------------------------------------------------------------------------------------------------------------#>
                if ($VMs) {
                    '          {
          "allOf": [
            {
              "field": "type",
              "equals": "Microsoft.Compute/virtualMachines"
            },
            {
              "not": {
                "allOf": [
                  {
                    "field": "Microsoft.Compute/virtualMachines/imageOffer",
                    "in": [' + "$vmImageOfferArray1" + ']
                  },
                  {
                    "field": "Microsoft.Compute/virtualMachines/imagePublisher",
                    "in": [' + "$vmImagePublisherArray1" + ']
                  },
                  {
                    "field": "Microsoft.Compute/virtualMachines/imageSku",
                     "in": [' + "$vmImageSkuArray1" + ']
                  },
                  {
                    "field": "Microsoft.Compute/virtualMachines/sku.name",
                    "in": [' + "$vmSizeArray1" + ']
                  }
                ]
              }
            }
           ]
        },'
                }

                <#-----------------------------------------------------------------------------------------------------------------------------------------#>
                if ($vmScaleSets) {
                    '          {
          "allof": [
            {
              "field": "type",
              "equals": "Microsoft.Compute/virtualMachineScaleSets"
            },
            {
              "not": {
                "field": "Microsoft.Compute/virtualMachineScaleSets/Sku.Name",
                "in": [' + "$vmScaleSetSKUNameArray1" + ']
                }
              }
            ]
          },'
                }

                <#-----------------------------------------------------------------------------------------------------------------------------------------#>
                if ($containerRegistries) {
                    '          {
          "allof": [
            {
              "field": "type",
              "equals": "Microsoft.ContainerRegistry/registries"
            },
            {
            "field": "Microsoft.ContainerRegistry/registries/sku.name",
            "notIn": [' + "$containerRegistrySKUArray1" + ']
            }
            ]
          },'
                }

                <#-----------------------------------------------------------------------------------------------------------------------------------------#>
                if ($eventHubs) {
                    '          {
          "allof": [
            {
              "field": "type",
              "equals": "Microsoft.EventHub/namespaces"
            },
            {
            "field": "Microsoft.EventHub/namespaces/sku.name",
            "notIn": [' + "$eventHubSKUArray1" + ']
            }
            ]
          },'
                }

                <#-----------------------------------------------------------------------------------------------------------------------------------------#>
                if ($keyVaults) {
                    '          {
          "allof": [
            {
              "field": "type",
              "equals": "Microsoft.KeyVault/vaults"
            },
            {
            "field": "Microsoft.KeyVault/vaults/sku.name",
            "notIn": [' + "$keyVaultSKUArray1" + ']
            }
            ]
          },'
                }

                <#-----------------------------------------------------------------------------------------------------------------------------------------#>
                if ($sqlDatabases) {
                    '         {
          "allof":[
            {
              "field": "type",
              "equals": "Microsoft.SQL/servers/databases"
            },
            {
              "not":{
                    "field": "Microsoft.Sql/servers/databases/requestedServiceObjectiveName",
                    "in": [' + "$sqlDBServiceObjectiveNameArray1" + ']
              }
            }
          ]
        },'
                }

                <#-----------------------------------------------------------------------------------------------------------------------------------------#>
                if ($storageAccounts) {
                    '            {
            "allOf": [
              {
                "source": "action",
                "equals": "Microsoft.Storage/storageAccounts/write"
              },
              {
                "field": "type",
                "equals": "Microsoft.Storage/storageAccounts"
              },
              {
                "not":
                  {
                    "field": "Microsoft.Storage/storageAccounts/sku.name",
                    "in": [' + "$storageSKUArray1" + ']
                  }
               }
            ]
          },'
                }

                <#-----------------------------------------------------------------------------------------------------------------------------------------#>
                if ($appGateways) {
                    '          {
          "allof": [
            {
              "field": "type",
              "equals": "Microsoft.Network/applicationGateways"
            },
            {
              "not": {
                "field": "Microsoft.Network/applicationGateways/Sku.Tier",
                "in": [' + "$appGatewaySKUTierArray1" + ']
                }
              }
            ]
          },'
                }

                <#-----------------------------------------------------------------------------------------------------------------------------------------#>
                if ($expressRoutes) {
                    '          {
          "allof": [
            {
              "field": "type",
              "equals": "Microsoft.Network/expressRouteCircuits"
            },
            {
              "not": {
                "field": "Microsoft.Network/expressRouteCircuits/Sku.Tier",
                "in": [' + "$expressRoutesSKUTierArray1" + ']
                }
              }
            ]
          },'
                }

                <#-----------------------------------------------------------------------------------------------------------------------------------------#>
                if ($lbs) {
                    '          {
          "allof": [
            {
              "field": "type",
              "equals": "Microsoft.Network/loadBalancers"
            },
            {
              "not": {
                "field": "Microsoft.Network/loadBalancers/Sku.Name",
                "in": [' + "$lbSKUNameArray1" + ']
                }
              }
            ]
          },'
                }

                <#-----------------------------------------------------------------------------------------------------------------------------------------#>
                if ($appServicePlans) {
                    '          {
          "allof": [
            {
              "field": "type",
              "equals": "Microsoft.Web/serverfarms"
            },
            {
              "not": {
                "field": "Microsoft.Web/serverfarms/sku.name",
                "in": [' + "$appServicePlanSKUNameArray1" + ']
                }
              }
            ]
          }'
                }

                <#-----------------------------------------------------------------------------------------------------------------------------------------#>
                '
      ]
    },
    "then": {
      "effect": "deny"
    }
}'
            }
        } policy -Passthru | Out-File -FilePath C:\Rbac-Policy\Policy\$RGName.json -Append

        function Rbac {
            Param(
                [switch]$Passthru
            )
            if ($Passthru) {
                '
{
  "Name": "' + "$rbacName" + '",
  "Id": null,
  "IsCustom": true,
  "Description": "Spektra Training Custom Role.",
  "Actions": [
     '
                $resourceTypesForRbac1
                '
    ],
  "NotActions": [
     ]
   }'
            }
        }
        Rbac -Passthru | Out-File -FilePath C:\Rbac-Policy\Rbac\$RGName.json -Append
        (Get-Content C:\Rbac-Policy\Rbac\$RGName.json) | ConvertFrom-Json | ConvertTo-Json -Depth 100 | Set-Content C:\Rbac-Policy\Rbac\$RGName.json
    }
} RGsOneByOne

Stop-Transcript
explorer C:\Rbac-Policy\
