########################
# DEPLOYMENTNINJAS.COM #
########################

<#
.SYNOPSIS
  Força o inventário de hardware do SCCM caso o computador tenha mudado de rede
  
.DESCRIPTION
  Ao detectar que o computador está em uma nova rede, força um "full hardware inventory".
  Útil para funcionamento do Windows PE PeerCache, conforme https://deploymentninjas.com/TÍTULO

.NOTES
  Versão:           1.0
  Autor:            Altimar de Souza Junior (altimar@deploymentninjas.com)
  Creation Date:    28/03/2018

  Versões futuras:  Tratar se o inventário de hardware ocorreu de forma full e com sucesso
  
#>

#---------------------------------Inicialização--------------------------------
$RegistryKeyPath = "HKLM:\Software\DTIC\SCCM" # Caminho da chave de registro para armazenar informações. Ex: "HKLM:\Software\SCCMInfo"


#------------------------------------Funções-----------------------------------
Function Set-Registry {
    <#
    .SYNOPSIS
    This function gives you the ability to create/change Windows registry keys and values. If you want to create a value but the key doesn't exist, it will create the key for you.
    .PARAMETER RegKey
    Path of the registry key to create/change
    .PARAMETER RegValue
    Name of the registry value to create/change
    .PARAMETER RegData
    The data of the registry value
    .PARAMETER RegType
    The type of the registry value. Allowed types: String,DWord,Binary,ExpandString,MultiString,None,QWord,Unknown. If no type is given, the function will use String as the type.
    .EXAMPLE 
    Set-Registry -RegKey HKLM:\SomeKey -RegValue SomeValue -RegData 1111 -RegType DWord
    This will create the key SomeKey in HKLM:\. There it will create a value SomeValue of the type DWord with the data 1111.
    .NOTES
    Author: Dominik Britz
    Source: https://github.com/DominikBritz
    #>
    [CmdletBinding()]
    PARAM
    (
        $RegKey,
        $RegValue,
        $RegData,
        [ValidateSet('String', 'DWord', 'Binary', 'ExpandString', 'MultiString', 'None', 'QWord', 'Unknown')]
        $RegType = 'String'    
    )

    If (-not $RegValue) {
        If (-not (Test-Path $RegKey)) {
            Write-Verbose "The key $RegKey does not exist. Try to create it."
            Try {
                New-Item -Path $RegKey -Force
            }
            Catch {
                Write-Error -Message $_
            }
            Write-Verbose "Creation of $RegKey was successfull"
        }        
    }

    If ($RegValue) {
        If (-not (Test-Path $RegKey)) {
            Write-Verbose "The key $RegKey does not exist. Try to create it."
            Try {
                New-Item -Path $RegKey -Force
                Set-ItemProperty -Path $RegKey -Name $RegValue -Value $RegData -Type $RegType -Force
            }
            Catch {
                Write-Error -Message $_
            }
            Write-Verbose "Creation of $RegKey was successfull"
        }
        Else {
            Write-Verbose "The key $RegKey already exists. Try to set value"
            Try {
                Set-ItemProperty -Path $RegKey -Name $RegValue -Value $RegData -Type $RegType -Force
            }
            Catch {
                Write-Error -Message $_
            }
            Write-Verbose "Creation of $RegValue in $RegKey was successfull"           
        }
    }
}

#-----------------------------------Execução-----------------------------------

# Obter último registro de rede
Clear-Variable LastSubnet
try {
    # Utilização de try-catch pois Get-ItemPropertyValue ignora o parâmetro "-ErrorAction SilentlyContinue"
    $LastSubnet = Get-ItemPropertyValue -Path $RegistryKeyPath -Name "Subnet"
}
catch {}

# Obter rede atual
$CurrentSubnet = (Get-WmiObject -Namespace "ROOT\ccm\InvAgt" -Class "CCM_NetworkAdapterConfiguration").IPSubnet

# Comparar redes
if ($LastSubnet -eq $CurrentSubnet) {
    Write-Output "Não houve mudança de rede.`nApenas atualizar registro."

    # Atualizar registro
    Set-Registry -RegKey $RegistryKeyPath -RegValue "Subnet" -RegData $CurrentSubnet -RegType String
    Set-Registry -RegKey $RegistryKeyPath -RegValue "Subnet Date" -RegData (Get-Date -Format "dd/MM/yy HH:mm:ss") -RegType String

}
else {
    Write-Output "Houve mudança de rede.`nRealizar inventário de hardware e atualizar registro."
    
    # Realizar inventário de hardware
    Get-WmiObject -Namespace root\ccm\invagt  -class InventoryActionStatus -filter "InventoryActionID = '{00000000-0000-0000-0000-000000000001}'" | Remove-WmiObject | Out-Null
    Invoke-WMIMethod -Namespace root\ccm -Class SMS_CLIENT -Name TriggerSchedule "{00000000-0000-0000-0000-000000000001}"

    # Atualizar registro
    Set-Registry -RegKey $RegistryKeyPath -RegValue "Subnet" -RegData $CurrentSubnet -RegType String
    Set-Registry -RegKey $RegistryKeyPath -RegValue "Subnet Date" -RegData (Get-Date -Format "dd/MM/yy HH:mm:ss") -RegType String
}
