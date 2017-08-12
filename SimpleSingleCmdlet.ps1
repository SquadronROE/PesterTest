<#
    Simple single cmdlet
#>

function Add-2Num
{
    param(
        [int]$num1,
        [int]$num2
    )
    $total = $num1 + $num2

    Write-Output "$num1 + $num2 = $total"
}