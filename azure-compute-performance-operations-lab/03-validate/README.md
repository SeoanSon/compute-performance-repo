# 03. 배포 검증하기

## 목표

VM 내부 서비스, Load Balancer probe/rule, Public IP, 외부 HTTP 경로를 순서대로 검증합니다.

## 실행

먼저 현재 세션을 복구합니다.

```powershell
$team = "team01"
$rg = "rg-compute-lab-$team"
$vmss = "vmss-order-$team"
$repoRoot = "C:\Users\seoanson\compute-performance-repo"
$labRoot = Join-Path $repoRoot "azure-compute-performance-operations-lab"
$lbName = az network lb list -g $rg --query "[0].name" -o tsv
$frontend = az network lb frontend-ip list -g $rg --lb-name $lbName -o json | ConvertFrom-Json
$publicIpId = $frontend[0].publicIPAddress.id
$pip = az network public-ip show --ids $publicIpId --query ipAddress -o tsv
```

샘플 API를 설치·검증합니다.

```powershell
& (Join-Path $labRoot "scripts\Install-WorkshopApi.ps1") `
  -ResourceGroup $rg `
  -VmssName $vmss
```

Load Balancer와 외부 경로를 확인합니다.

```powershell
az network lb probe list -g $rg --lb-name $lbName -o table
az network lb rule list -g $rg --lb-name $lbName -o table
curl.exe -fsS "http://$pip/healthz"
curl.exe -fsS "http://$pip/readyz"
curl.exe -fsS "http://$pip/api/orders"
```

## 통과 기준

- helper 성공 메시지 출력
- probe가 port 80, `/healthz`
- `LBRule`이 frontend 80 → backend 80
- 세 URL 모두 HTTP 200

실패하면 [`../DEPLOYMENT.md`](../DEPLOYMENT.md)의 연결 문제 진단만 수행하고 다음 단계로 가지 않습니다.

## 다음 단계

[`../04-baseline/README.md`](../04-baseline/README.md)

