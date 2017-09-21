
function Login-Credentials 
{
    # Wraps the login as a stub so we can expand it later - automating login to azure
    Login-AzureRmAccount
}

function Add-WindowsDesktopVM
{
    <#
    .SYNOPSIS
    Adds a Windows desktop VM to a specified resource group, or creates a resource group if none is specified (from the name of the project)
    
    .DESCRIPTION
    Uses built-in Azure cmdlets to create a Windows 10 desktop with default settings, inside a given Resource Group.
    
    .PARAMETER RGName
    The name of the Resource Group to be used for the VM and associated virtual hardware.

    .PARAMETER Project
    If no RG name is used, giving a project name will allow one to be created
    
    .PARAMETER VMPurpose
    A simple statement describing purpose of the VM, to be used in naming the VM and associated hardware. ex. DevClient, WebClient
    
    .PARAMETER PSCred
    A Credential object that has been created some other way and passed to this cmdlet. If this is null, the user will be prompted to log in to their Azure account.

    .EXAMPLE
    Add-WindowsDesktopVM -Project PesterDev -VMPurpose DevClient
    
    .NOTES
    This cmdlet can be called multiple times to set up individual VMs with their own associated virtual networks and hardware. All will be standard, and will leave the user with the ability to login via RDP.
    #> 
    param(
        [string]$RGName,
        [string]$Project,
        [parameter(mandatory=$true)][string]$VMPurpose
    ) 

    $ErrorActionPreference="Stop"
#Login-AzureRmAccount -Credential $psCred -- can't do this because of Blackbaud's SSO
Write-Output "Project: $Project , RGName: $RGName , VMPurpose: $VMPurpose"
If ([string]::IsNullOrEmpty($RGName))
{
    $RGName="$Project-RG"
    Write-Output "RGName: $RGName"
    New-AzureRmResourceGroup -Name $RGName -Location WestUS2
}

# Create a subnet configuration
$subnetConfig = New-AzureRmVirtualNetworkSubnetConfig -Name "$RGName-Subnet" -AddressPrefix 192.168.1.0/24

# Create a virtual network
$vnet = New-AzureRmVirtualNetwork -ResourceGroupName $RGName -Location WestUS2 -Name "$RGName-VNet" -AddressPrefix 192.168.0.0/16 -Subnet $subnetConfig

# Create a public IP address and specify a DNS name
$pip = New-AzureRmPublicIpAddress -ResourceGroupName $RGName -Location WestUS2 -AllocationMethod Static -IdleTimeoutInMinutes 4 -Name "$RGName-PublicDNS$(Get-Random)"

# Create an inbound network security group rule for port 3389
$nsgRuleRDP = New-AzureRmNetworkSecurityRuleConfig -Name "$RGName-RDP" -Protocol Tcp -Direction Inbound -Priority 1000 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 3389 -Access Allow

# Create an inbound network security group rule for port 80
$nsgRuleWeb = New-AzureRmNetworkSecurityRuleConfig -Name "$RGName-WWW" -Protocol Tcp -Direction Inbound -Priority 1001 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 80 -Access Allow

# Create a network security group
$nsg = New-AzureRmNetworkSecurityGroup -ResourceGroupName $RGName -Location WestUS2 -Name "$RGName-NSG" -SecurityRules $nsgRuleRDP,$nsgRuleWeb

# Create a virtual network card and associate with public IP address and NSG
$nic = New-AzureRmNetworkInterface -Name "$RGName-$VMPurpose-NIC" -ResourceGroupName "$RGName" -Location WestUS2 -SubnetId $vnet.Subnets[0].Id -PublicIpAddressId $pip.Id -NetworkSecurityGroupId $nsg.Id

# Create a storage account
$StorageAccountName = $Project.ToLower() + $VMPurpose.ToLower()
$StorageAccount = New-AzureRmStorageAccount -ResourceGroupName $RGName -Name "$StorageAccountName" -Type "Standard_LRS" -Location "WestUS2"

$VMAccountName ="$VMPurpose-User1"
$VMPassword = ConvertTo-SecureString "Th1s !s a bad password" -AsPlainText -Force
$Cred = New-Object System.Management.Automation.PSCredential($VMAccountName, $VMPassword)

# Create a virtual machine configuration
$OSDiskUri = $StorageAccount.PrimaryEndpoints.Blob.ToString() + "vhds/$VMPurpose-OSDisk.vhd"
$vmConfig = New-AzureRmVMConfig -VMName "$RGName-$VMPurpose" -VMSize "Standard_D3_v2" | Set-AzureRmVMOperatingSystem -Windows -ComputerName "$VMPurpose" -Credential $cred | Set-AzureRmVMSourceImage -PublisherName "MicrosoftWindowsDesktop" -Offer "Windows-10" -Skus "RS2-Pro" -Version "15063.0.540" | Add-AzureRmVMNetworkInterface -Id $nic.Id
Set-AzureRMVMOSDisk -VM $vmConfig -Name "$VMPurpose-OSDisk" -VhdUri $OSDiskUri -CreateOption FromImage

New-AzureRmVM -ResourceGroupName $RGName -Location WestUS2 -VM $vmConfig
}

function Add-WindowsServerVM
{
    <#
    .SYNOPSIS
    Adds a Windows Server VM to a specified resource group, or creates a resource group if none is specified (from the name of the project)
    
    .DESCRIPTION
    Uses built-in Azure cmdlets to create a Windows 10 desktop with default settings, inside a given Resource Group.
    
    .PARAMETER RGName
    The name of the Resource Group to be used for the VM and associated virtual hardware. If none is specified one will be created using standard naming scheme.

    .PARAMETER Project
    If no RG name is used, giving a project name will allow one to be created
    
    .PARAMETER VMPurpose
    A simple statement describing purpose of the VM, to be used in naming the VM and associated hardware. ex. DevClient, WebClient
    
    .PARAMETER PSCred
    A Credential object that has been created some other way and passed to this cmdlet. If this is null, the user will be prompted to log in to their Azure account.

    .PARAMETER NewVNet
    Boolean describing whether a new VNet should be used. Defaults to true, so a new VNet is created.

    .EXAMPLE
    Add-WindowsServerVM -RGName PesterDev-RG -Project PesterDev -VMPurpose DevClient -NewVNet $False
    
    .NOTES
    This cmdlet can be called multiple times to set up individual VM servers with their own associated virtual networks and hardware. All will be standard, and will leave the user with the ability to login via RDP.
    #>
    param(
        [string]$RGName,
        [string]$Project,
        [parameter(mandatory=$true)][string]$VMPurpose,
        [bool]$NewVNet=$true
    ) 

    $ErrorActionPreference="Stop"

Write-Output "Project: $Project, RGName: $RGName, VMPurpose: $VMPurpose"
If ([string]::IsNullOrEmpty($RGName))
{
    $RGName="$Project-RG"
    Write-Output "RGName: $RGName"
    New-AzureRmResourceGroup -Name $RGName -Location WestUS2
}

# Create a subnet configuration
$subnetConfig = New-AzureRmVirtualNetworkSubnetConfig -Name "$RGName-SrvSubnet" -AddressPrefix 192.168.1.0/24

# Create a virtual network, checking to see if one is already created
If ([string]::IsNullOrEmpty($VNet))
{
    $vnet = New-AzureRmVirtualNetwork -ResourceGroupName $RGName -Location WestUS2 -Name "$RGName-VNet" -AddressPrefix 192.168.0.0/16 -Subnet $subnetConfig
}
else
{
    $vnet = Get-AzureRmVirtualNetwork -ResourceGroupName $RGName -Name "$RGName-VNet"    
}
# Create a public IP address and specify a DNS name
$pip = New-AzureRmPublicIpAddress -ResourceGroupName $RGName -Location WestUS2 -AllocationMethod Static -IdleTimeoutInMinutes 4 -Name "$RGName-PublicDNS$(Get-Random)"

# Create an inbound network security group rule for port 3389
$nsgRuleRDP = New-AzureRmNetworkSecurityRuleConfig -Name "$RGName-SrvRDP" -Protocol Tcp -Direction Inbound -Priority 1000 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 3389 -Access Allow

# Create an inbound network security group rule for port 80
$nsgRuleWeb = New-AzureRmNetworkSecurityRuleConfig -Name "$RGName-SrvWWW" -Protocol Tcp -Direction Inbound -Priority 1001 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 80 -Access Allow

# Create a network security group
$nsg = New-AzureRmNetworkSecurityGroup -ResourceGroupName $RGName -Location WestUS2 -Name "$RGName-SrvNSG" -SecurityRules $nsgRuleRDP,$nsgRuleWeb

# Create a virtual network card and associate with public IP address and NSG
$nic = New-AzureRmNetworkInterface -Name "$RGName-$VMPurpose-NIC" -ResourceGroupName "$RGName" -Location WestUS2 -SubnetId $vnet.Subnets[0].Id -PublicIpAddressId $pip.Id -NetworkSecurityGroupId $nsg.Id

# Create a storage account
$StorageAccountName = $Project.ToLower() + $VMPurpose.ToLower()
$StorageAccount = New-AzureRmStorageAccount -ResourceGroupName $RGName -Name "$StorageAccountName" -Type "Standard_LRS" -Location "WestUS2"

$VMAccountName ="$VMPurpose-SrvUser1"
$VMPassword = ConvertTo-SecureString "Th1s !s a bad password" -AsPlainText -Force
$Cred = New-Object System.Management.Automation.PSCredential($VMAccountName, $VMPassword)

# Create a virtual machine configuration
$OSDiskUri = $StorageAccount.PrimaryEndpoints.Blob.ToString() + "vhds/$VMPurpose-OSDisk.vhd"
$vmConfig = New-AzureRmVMConfig -VMName "$RGName-$VMPurpose" -VMSize "Standard_D3_v2" | Set-AzureRmVMOperatingSystem -Windows -ComputerName "$VMPurpose" -Credential $cred | Set-AzureRmVMSourceImage -PublisherName "MicrosoftWindowsServer" -Offer "WindowsServer" -Skus "2016-Datacenter-Server-Core" -Version "2016.127.20170712" | Add-AzureRmVMNetworkInterface -Id $nic.Id
Set-AzureRMVMOSDisk -VM $vmConfig -Name "$VMPurpose-OSDisk" -VhdUri $OSDiskUri -CreateOption FromImage

New-AzureRmVM -ResourceGroupName $RGName -Location WestUS2 -VM $vmConfig
}