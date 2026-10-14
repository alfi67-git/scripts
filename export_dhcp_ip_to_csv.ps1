# =============================================
# OBJECTIF : Extraire les IP probables des switchs
# SOURCE : DHCP Windows - Option 003 (Routeur)
# IMPACT : Lecture seule sur le DHCP
# =============================================

Import-Module DhcpServer -ErrorAction Stop

# Configuration
$DHCPServer = "nom-dns-dhcp-server"

$Reseaux = @(
    "192.168",
)

$ExportCSV = "C:\Users\alfi\Desktop\switchs.csv"

# Récupération des étendues actives
$Scopes = Get-DhcpServerv4Scope `
    -ComputerName $DHCPServer `
    -ErrorAction Stop |
    Where-Object {

        $ScopeIP = $_.ScopeId.ToString()
        $Prefixe = ($ScopeIP -split '\.')[0..1] -join "."

        $Prefixe -in $Reseaux -and
        $ScopeIP -like "*.0" -and
        $_.State -eq "Active"
    }

# Recherche des switchs
$Switchs = foreach ($Scope in $Scopes) {

    # Sécurité : logique .1/.254 réservée aux /24
    if ($Scope.SubnetMask.ToString() -ne "255.255.255.0") {
        Write-Warning "Etendue ignoree (non /24) : $($Scope.ScopeId)"
        continue
    }

    # Récupération de l'option DHCP 003
    $Option = Get-DhcpServerv4OptionValue `
        -ComputerName $DHCPServer `
        -ScopeId $Scope.ScopeId `
        -OptionId 3 `
        -ErrorAction SilentlyContinue

    if (-not $Option) {
        Write-Warning "Aucun routeur pour $($Scope.ScopeId)"
        continue
    }

    foreach ($Routeur in $Option.Value) {

        $IPRouteur = $Routeur.ToString()
        $Octets = $IPRouteur.Split(".")

        # Vérifie que le routeur appartient à l'étendue
        $PrefixeRouteur = ($Octets[0..2] -join ".")
        $PrefixeReseau = (
            $Scope.ScopeId.ToString().Split(".")[0..2] -join "."
        )

        if ($PrefixeRouteur -ne $PrefixeReseau) {
            Write-Warning "Routeur hors etendue : $IPRouteur"
            continue
        }

        # Détermination de l'IP du switch
        if ($Octets[3] -eq "1") {
            $IPSwitch = "$PrefixeReseau.254"
        }
        elseif ($Octets[3] -eq "254") {
            $IPSwitch = "$PrefixeReseau.1"
        }
        else {
            Write-Warning "Routeur non reconnu : $IPRouteur"
            continue
        }

        # Préparation du résultat
        [PSCustomObject]@{
            Nom     = "$($Scope.ScopeId) - $($Scope.Name)"
            Reseau  = $Scope.ScopeId.ToString()
            IP      = $IPSwitch
            Routeur = $IPRouteur
        }
    }
}

# Suppression des doublons
$Switchs = @(
    $Switchs |
    Sort-Object IP -Unique
)

# Affichage
$Switchs | Format-Table -AutoSize

# Export CSV
$Switchs | Export-Csv `
    -Path $ExportCSV `
    -Delimiter ";" `
    -NoTypeInformation `
    -Encoding UTF8

Write-Host ""
Write-Host "Export termine : $ExportCSV" -ForegroundColor Green
Write-Host "Nombre d'IP candidates : $($Switchs.Count)"
