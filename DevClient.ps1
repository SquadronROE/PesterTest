Login-AzureRmAccount

$RGName = '$Env:USERNAME-PSDev'
New-AzureRmResourceGroup -Name $RGName -Location WestUS2

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
$nic = New-AzureRmNetworkInterface -Name '$RGName-DevClientNIC' -ResourceGroupName '$RGName-NIC' -Location WestUS2 -SubnetId $vnet.Subnets[0].Id -PublicIpAddressId $pip.Id -NetworkSecurityGroupId $nsg.Id

$cred = Get-Credential -UserName $Env:USERNAME

# Create a virtual machine configuration
$vmConfig = New-AzureRmVMConfig -VMName '$RGName-PSDevClient' -VMSize Standard_DS2 | Set-AzureRmVMOperatingSystem -Windows -ComputerName '$RGName-PSDevClient' -Credential $cred | Set-AzureRmVMSourceImage -PublisherName MicrosoftVisualStudio -Offer VisualStudio | Add-AzureRmVMNetworkInterface -Id $nic.Id

New-AzureRmVM -ResourceGroupName $RGName -Location $WestUS2 -VM $vmConfig