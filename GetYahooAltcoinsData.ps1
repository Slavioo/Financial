$baseUrl = "https://query1.finance.yahoo.com/v7/finance/download/"
$outputFolder = ".\data"
$jsonFilePath = ".\altcoins.json"
$startDate = [int][double]::Parse((Get-Date (Get-Date).AddDays(-365) -UFormat %s))
$endDate = [int][double]::Parse((Get-Date -UFormat %s))
$interval = "1d"
$currency = "USD"
$jsonContent = Get-Content $jsonFilePath -Raw | ConvertFrom-Json
$symbols = $jsonContent.altcoins

foreach ($symbol in $symbols) {
    $url = $baseUrl + $symbol + "-" + $currency + "?period1=" + $startDate + "&period2=" + $endDate + "&interval=" + $interval
    $extractFolderPath = Join-Path $outputFolder "extract"
    $transformFolderPath = Join-Path $outputFolder "transform"
    if (-not (Test-Path $extractFolderPath)) {
        New-Item -ItemType Directory -Path $extractFolderPath | Out-Null
    }
    if (-not (Test-Path $transformFolderPath)) {
        New-Item -ItemType Directory -Path $transformFolderPath | Out-Null
    }
    $extractFilePath = Join-Path $extractFolderPath "$symbol.csv"
    $transformFilePath = Join-Path $transformFolderPath "$symbol.csv"
    
    Invoke-WebRequest -Uri $url -OutFile $extractFilePath
    
    $csv = Import-Csv $extractFilePath
    $csv = $csv | Sort-Object {[DateTime]::ParseExact($_.Date, "yyyy-MM-dd", $null)} -Descending
    
    for ($i = 0; $i -lt $csv.Count; $i++) {
        foreach ($sma in @(20, 50, 100)) {
            $smaColName = "SMA$sma"
            $smaUpperColName = "SMA$sma" + "Upper"
            $smaLowerColName = "SMA$sma" + "Lower"
            $smaVal = 0.0
            $smaUpperVal = 0.0
            $smaLowerVal = 0.0
            
            if ($i -ge ($sma - 1)) {
                for ($j = $i - ($sma - 1); $j -le $i; $j++) {
                    $smaVal += [double]$csv[$j].Close
                }
                $smaVal /= $sma
                
                $smaStdDev = 0.0
                for ($j = $i - ($sma - 1); $j -le $i; $j++) {
                    $smaStdDev += ([double]$csv[$j].Close - $smaVal) * ([double]$csv[$j].Close - $smaVal)
                }
                $smaStdDev /= $sma
                $smaStdDev = [Math]::Sqrt($smaStdDev)
                $smaUpperVal = $smaVal + 2 * $smaStdDev
                $smaLowerVal = $smaVal - 2 * $smaStdDev
            }
            
            $csv[$i] | Add-Member -NotePropertyName $smaColName -NotePropertyValue $smaVal
            $csv[$i] | Add-Member -NotePropertyName $smaUpperColName -NotePropertyValue $smaUpperVal
            $csv[$i] | Add-Member -NotePropertyName $smaLowerColName -NotePropertyValue $smaLowerVal
        }
    }
    
    $csv | Export-Csv $transformFilePath -NoTypeInformation
    Remove-Item "$extractFilePath\$symbol.csv"
}