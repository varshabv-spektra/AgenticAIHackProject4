# =====================================================================================
# Export-ResourceSnapshot.ps1
# Updated to use the Az PowerShell module (AzureRM is retired / no longer available).
# =====================================================================================
 
# ---- Sign in ---------------------------------------------------------------
# If interactive browser sign-in fails with a "window handle" error (common on
# RDP/lab VMs and Server Core), use device code sign-in instead.
Connect-AzAccount -UseDeviceAuthentication
 
# ---- Ensure output folder exists -------------------------------------------
$outputFolder = "C:\GoldenSnapshots"
if (-not (Test-Path -Path $outputFolder)) {
    New-Item -ItemType Directory -Path $outputFolder -Force | Out-Null
}
 
$RGs = "contosofoundry-demo-rg", "lab-vm"
 
foreach ($RG in $RGs) {
    $RGName = $RG
    Write-Host "======================================================="
    Write-Host "Resource Group Name :" $RGName
    Write-Host "======================================================="
 
    $resources = Get-AzResource -ResourceGroupName $RGName
 
    $csvPath = Join-Path $outputFolder "$RGName.csv"
 
    # Create csv file with header (overwrite if it already exists from a prior run)
    Set-Content -Path $csvPath -Value '"ResourceGroupName","ResourceName","ResourceType","SKUName","SKUTier","SKUSize","Region","ResourceId"'
 
    foreach ($resource in $resources) {
        $resourceType = $resource.ResourceType
        $skuName = $resource.Sku.Name
        $skuTier = $resource.Sku.Tier
        $skuSize = $null
 
        if ($resourceType -eq "Microsoft.Compute/virtualMachines") {
            $VM = Get-AzVM -ResourceGroupName $RGName -Name $resource.Name
            $skuSize = $VM.HardwareProfile.VmSize
        }
 
        [pscustomobject]@{
            ResourceGroupName = $RGName
            ResourceName      = $resource.Name
            ResourceType      = $resource.ResourceType
            SKUName           = $skuName
            SKUTier           = $skuTier
            SKUSize           = $skuSize
            Region            = $resource.Location
            ResourceId        = $resource.ResourceId
        } | Export-Csv -Path $csvPath -Append -NoTypeInformation
    }
}
