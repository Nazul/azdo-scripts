# Load Azure DevOps configuration from .env file into environment variables
# Check if .env file exists
$envFilePath = Join-Path $PSScriptRoot ".env"
if (Test-Path $envFilePath) {
    Get-Content $envFilePath | ForEach-Object {
        if ($_ -match '^([^#=]+)=(.*)$') {
            $name = $matches[1].Trim()
            $value = $matches[2].Trim()
            [Environment]::SetEnvironmentVariable($name, $value, 'Process')
        }
    }
    Write-Host "Loaded configuration from .env file"
} else {
    Write-Warning ".env file not found at $envFilePath"
}

# Read values from 1Password using environment variables
op signin
$organization = op read $env:AZDOORG
$project = op read $env:AZDOPROJ
$pat = op read $env:AZDOPAT

# Ask for the team name
$teamName = Read-Host "Enter the team name"

# Create authentication header
$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$pat"))
$headers = @{
    Authorization = "Basic $base64AuthInfo"
    "Content-Type" = "application/json"
}

# Get project iterations
$iterationsUri = "$organization/$project/_apis/work/teamsettings/iterations?api-version=7.1"
$iterations = Invoke-RestMethod -Uri $iterationsUri -Headers $headers -Method Get

$iterations = $iterations.value | Where-Object {$_.path -like '*FY26*'}

# Assign iterations to team
foreach ($iteration in $iterations) {
    $assignUri = "$organization/$project/$teamName/_apis/work/teamsettings/iterations?api-version=7.1"
    $body = @{
        id = $iteration.id
    } | ConvertTo-Json
    
    try {
        Invoke-RestMethod -Uri $assignUri -Headers $headers -Method Post -Body $body
        Write-Host "Assigned iteration '$($iteration.name)' to team '$teamName'"
    }
    catch {
        Write-Warning "Failed to assign iteration '$($iteration.name)': $($_.Exception.Message)"
    }
}

# EOF
