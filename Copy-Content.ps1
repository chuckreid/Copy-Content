function Copy-LabContent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Source,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Destination,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string[]]$Labs,

        [Parameter()]
        [ValidateRange(1, 100)]
        [int]$Concurrent = 5
    )

    $labRoot = "\\K202DC1\Labs"
    $jobs = New-Object System.Collections.Generic.List[System.Management.Automation.Job]

    foreach ($lab in $Labs) {
        $csvPath = Join-Path -Path $labRoot -ChildPath ("{0}.csv" -f $lab)
        if (-not (Test-Path -LiteralPath $csvPath)) {
            Write-Warning "CSV not found for lab '$lab' at $csvPath"
            continue
        }

        $records = Import-Csv -LiteralPath $csvPath
        foreach ($record in $records) {
            $computerName = $null
            if ($record.PSObject.Properties.Name -contains 'ComputerName') {
                $computerName = $record.ComputerName
            } else {
                $computerName = $record.PSObject.Properties.Value | Select-Object -First 1
            }

            if (-not $computerName) {
                Write-Warning "Skipping blank computer name in $csvPath"
                continue
            }

            $targetPath = if ($Destination -match '\{Computer\}') {
                $Destination -replace '\{Computer\}', $computerName
            } else {
                $Destination
            }

            while ($jobs.Count -ge $Concurrent) {
                $finished = Wait-Job -Job $jobs -Any
                $jobs.Remove($finished) | Out-Null
            }

            $jobs.Add(
                Start-Job -ScriptBlock {
                    param($sourcePath, $destPath)
                    Copy-Item -Path $sourcePath -Destination $destPath -Recurse -Force
                } -ArgumentList $Source, $targetPath
            ) | Out-Null
        }
    }

    if ($jobs.Count -gt 0) {
        Wait-Job -Job $jobs | Out-Null
        Receive-Job -Job $jobs | Out-Null
        Remove-Job -Job $jobs
    }
}

Export-ModuleMember -Function Copy-LabContent
