########################
# DEPLOYMENTNINJAS.COM #
########################

<#
.SYNOPSIS
  Remove todos aplicativos desativados (retired)
  
.DESCRIPTION
  Auxilia na tarefa de limpeza do SCCM, removendo os aplicativos desativados (retired)
  IMPORTANTE: É necessário ter o módulo do SCCM instalado no computador

.PARAMETER SiteCOde
    Código de site do SCCM. Exemplo: A01

.PARAMETER ProviderMachineName
    Servidor que possui a role SMS Provider instalada.
    Normalmente, é o servidor principal.
    Saiba mais em https://docs.microsoft.com/en-us/sccm/core/plan-design/hierarchy/plan-for-the-sms-provider

.NOTES
  Versão:           1.0
  Autor:            Altimar de Souza Junior (altimar@deploymentninjas.com)
  Creation Date:    01/03/2018
  
.EXAMPLE
  Remove-RetiredApps -SiteCode "A01" -ProviderMachineName "CMSERVER.contoso.com"
#>

#----------------------------------Parâmetros----------------------------------

[CmdletBinding()]
Param(
    # Definir código do site do SCCM
    [Parameter(Mandatory = $true)]
    [string]$SiteCode,
    # Definir servidor com a role SMS Provider
    # Por padrão, o site principal - 
    [Parameter(Mandatory = $true)]
    [string]$ProviderMachineName
)

#---------------------------------Inicialização--------------------------------

# Configurar conexão com servidor SCCM
$initParams = @{}
if ((Get-Module ConfigurationManager) -eq $null) {
    Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1" @initParams 
}
if ((Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue) -eq $null) {
    New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $ProviderMachineName @initParams
}
Set-Location "$($SiteCode):\" @initParams

#-----------------------------------Execução-----------------------------------

# Listar aplicativos desativados
try {
    Write-Host "Listar aplicativos desativados: " -NoNewline
    $TodosAplicativosDesativados = Get-CMApplication -Fast | Where-Object {$_.IsExpired -eq "True"} | Select-Object LocalizedDisplayName, IsExpired
    Write-Host "OK" -ForegroundColor Green
}
catch {
    Write-Host "`tErro: $($_.Exception.Message)" -ForegroundColor Red
}

# Remover aplicativos desativados
if ($TodosAplicativosDesativados) {
    foreach ($AplicativoDesativado in $TodosAplicativosDesativados) {
        Write-Host "Removendo $($AplicativoDesativado.LocalizedDisplayName): " -NoNewline -ForegroundColor Yellow
        try {
            Remove-CMApplication -Name $AplicativoDesativado.LocalizedDisplayName -Force
            Write-Host "`tOK" -ForegroundColor Green
        }
        catch {
            Write-Host "`tErro: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}
else {
    Write-Host "Não foram encontrados aplicativos desativados!" -ForegroundColor Yellow
}
