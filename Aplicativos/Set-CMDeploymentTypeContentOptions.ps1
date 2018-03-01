########################
# DEPLOYMENTNINJAS.COM #
########################

<#
.SYNOPSIS
  Configura opções conteúdo do "tipo de implantação" de todos aplicativos
  
.DESCRIPTION
  Configura as seguintes opções:
  "Permitir que os clientes compartilhem conteúdo com outros clientes da mesma subrede", relacionada ao BranchCache
  "Permitir que os clientes usem pontos de distribuição do grupo de limites de site padrão", relacionada a quando conteúdo não está disponível em um distribution point preferencial
  "Baixar conteúdo do ponto de distribuição e executar localmente", relacionada a clientes que estão em grupo de limites vizinho ou grupo de limites de site padrão

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
  Set-CMDeploymentTypeContentOptions -SiteCode "A01" -ProviderMachineName "CMSERVER.contoso.com"
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

# Listar todos aplicativos
try {
    Write-Host "Listar todos aplicativos: " -NoNewline
    $TodosAplicativos = Get-cmapplication -Fast | Select-Object LocalizedDisplayName
    Write-Host "`tOK" -ForegroundColor Green
}
catch {
    Write-Host "`tErro: $($_.Exception.Message)" -ForegroundColor Red
}

# Configurar opções de conteúdo de todos aplicativos

if ($TodosAplicativos){
    foreach ($Aplicativo in $TodosAplicativos) {     
        Write-Host "-------------------------------------------------------------" -ForegroundColor Yellow
        Write-Host  ("Verificando aplicativo " + $Aplicativo.LocalizedDisplayName) -ForegroundColor Yellow
        $TodosDeploymentTypes = Get-CMDeploymentType -ApplicationName $Aplicativo.LocalizedDisplayName
        Foreach ($DeploymentType in $TodosDeploymentTypes) {
            Write-Host  ("Processando deployment type " + $DeploymentType.LocalizedDisplayName) -ForegroundColor Cyan -NoNewline
            try {
                Set-CMDeploymentType -InputObject $DeploymentType -EnableBranchCache $True -EnableContentLocationFallback $true -OnSlowNetworkMode Download -MsiOrScriptInstaller
                Write-Host "`tOK" -ForegroundColor Green
            }
            catch {
                Write-Host "`tErro: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }
}
else {
    Write-Host "Não foram encontrados aplicativos!" -ForegroundColor Yellow
}
