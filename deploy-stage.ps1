param(
  [string] $Server     = "stage.childmetrix.com",
  [string] $RemotePath = "/var/www/stage.childmetrix.com/html",
  [switch] $MdOnly
)

# Precompute remote targets (quoted so PS doesn't misparse the colon)
$TargetRoot = "root@${Server}:${RemotePath}/"
$TargetMd   = "root@${Server}:${RemotePath}/md/"

# 1) Backup on the server (runs entirely on the remote)
ssh "root@$Server" 'mkdir -p ~/deploy-backups && tar -czf ~/deploy-backups/html-$(date +%F-%H%M%S).tar.gz -C /var/www/stage.childmetrix.com html'

# 2) Deploy
if ($MdOnly) {
  Write-Host "Deploying MD only..." -ForegroundColor Cyan
  scp -r .\md\* "$TargetMd"
} else {
  Write-Host "Deploying full site..." -ForegroundColor Cyan
  scp -r .\_assets    "$TargetRoot"
  scp -r .\ky         "$TargetRoot"
  scp -r .\md         "$TargetRoot"
  scp    .\index.html "$TargetRoot"
  scp    .\style.css  "$TargetRoot"
}

Write-Host "Done." -ForegroundColor Green
