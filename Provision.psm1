#For debug/test purposes
function Add-Credentials 
{
    $azureAccountName ="Sean.Long@Blackbaud.me"
    $azurePassword = ConvertTo-SecureString "" -AsPlainText -Force
    $global:psCred = New-Object System.Management.Automation.PSCredential($azureAccountName, $azurePassword)
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
    Add-WindowsDesktopVM -Project PesterDev -VMPurpose DevClient -PSCred $PSCred
    
    .NOTES
    This cmdlet can be called multiple times to set up individual VMs with their own associated virtual networks and hardware. All will be standard, and will leave the user with the ability to login via RDP.
    #> 
    param(
        [string]$RGName,
        [string]$Project,
        [parameter(mandatory=$true)][string]$VMPurpose,
        $PSCred
    ) 

    $ErrorActionPreference="Stop"
Login-AzureRmAccount -Credential $psCred
If ($RGName -eq $null)
{
    $RGName='$Project-RG'
    New-AzureRmResourceGroup -Name $RGName -Location WestUS2
}

# Create a subnet configuration
$subnetConfig = New-AzureRmVirtualNetworkSubnetConfig -Name '$RGName-Subnet' -AddressPrefix 192.168.1.0/24

# Create a virtual network
$vnet = New-AzureRmVirtualNetwork -ResourceGroupName $RGName -Location WestUS2 -Name '$RGName-VNet' -AddressPrefix 192.168.0.0/16 -Subnet $subnetConfig

# Create a public IP address and specify a DNS name
$pip = New-AzureRmPublicIpAddress -ResourceGroupName $RGName -Location WestUS2 -AllocationMethod Static -IdleTimeoutInMinutes 4 -Name "$RGName-PublicDNS$(Get-Random)"

# Create an inbound network security group rule for port 3389
$nsgRuleRDP = New-AzureRmNetworkSecurityRuleConfig -Name '$RGName-RDP' -Protocol Tcp -Direction Inbound -Priority 1000 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 3389 -Access Allow

# Create an inbound network security group rule for port 80
$nsgRuleWeb = New-AzureRmNetworkSecurityRuleConfig -Name '$RGName-WWW' -Protocol Tcp -Direction Inbound -Priority 1001 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 80 -Access Allow

# Create a network security group
$nsg = New-AzureRmNetworkSecurityGroup -ResourceGroupName $RGName -Location WestUS2 -Name '$RGName-NSG' -SecurityRules $nsgRuleRDP,$nsgRuleWeb

# Create a virtual network card and associate with public IP address and NSG
$nic = New-AzureRmNetworkInterface -Name '$RGName-$VMPurpose-NIC' -ResourceGroupName '$RGName-NIC' -Location WestUS2 -SubnetId $vnet.Subnets[0].Id -PublicIpAddressId $pip.Id -NetworkSecurityGroupId $nsg.Id

$cred = Get-Credential -UserName $Env:USERNAME

# Create a virtual machine configuration
$vmConfig = New-AzureRmVMConfig -VMName '$RGName-$VMPurpose' -VMSize Standard_DS2 | Set-AzureRmVMOperatingSystem -Windows -ComputerName '$RGName-$VMPurpose' -Credential $cred | Set-AzureRmVMSourceImage -PublisherName MicrosoftWindowsDesktop -Offer Windows-10 | Add-AzureRmVMNetworkInterface -Id $nic.Id

New-AzureRmVM -ResourceGroupName $RGName -Location $WestUS2 -VM $vmConfig
}