param(
  [string] $Host   = "stage.childmetrix.com",
  [string] $Remote = "/var/www/stage.childmetrix.com/html",
  [switch] $MdOnly
)

# 1) Backup the server's current html folder (timestamped)
ssh root@$Host "mkdir -p ~/deploy-backups && tar -czf ~/deploy-backups/html-$(date +%F-%H%M%S).tar.gz -C /var/www/stage.childmetrix.com html"

# 2) Deploy
if ($MdOnly) {
  Write-Host "Deploying MD only..." -ForegroundColor Cyan
  scp -r .\md\*        root@$Host:$Remote/md/
} else {
  Write-Host "Deploying full site..." -ForegroundColor Cyan
  scp -r .\_assets     root@$Host:$Remote/
  scp -r .\ky          root@$Host:$Remote/
  scp -r .\md          root@$Host:$Remote/
  scp    .\index.html  root@$Host:$Remote/
  scp    .\style.css   root@$Host:$Remote/
}

Write-Host "Done." -ForegroundColor Green
