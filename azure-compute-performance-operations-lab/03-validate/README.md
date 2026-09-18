# 03. 배포 검증하기

## 목표

VM 내부 서비스, Load Balancer probe/rule, Public IP, 외부 HTTP 경로를 순서대로 검증합니다.

## 이 단계에서 배우는 것

- 장애를 **애플리케이션 내부 → VM 포트 → NSG → backend pool → Load Balancer → Public IP** 순서로 좁히는 방법
- `Running`, `Listening`, `Healthy`, `HTTP 200`이 서로 다른 상태라는 점
- 외부 접속 실패를 바로 부하 테스트나 SKU 문제로 해석하지 않는 방법

## 관찰 포인트

| 확인 위치 | 확인할 것 | 실패 시 의미 |
|---|---|---|
| VM service | `order-api` active | 서비스가 실행되지 않음 |
| VM port | TCP 80 listener | 포트 충돌 또는 프로세스 문제 |
| Probe | `/healthz` 200 | LB가 backend를 제외할 수 있음 |
| Rule | frontend 80 → backend 80 | 외부 경로가 없음 |
| Public IP | frontend 연결 여부 | 올바른 진입점이 아님 |

## 실행

먼저 현재 세션을 복구합니다.

```powershell
$team = "team01"
$rg = "rg-compute-lab-$team"
$vmss = "vmss-order-$team"
$repoRoot = "C:\Users\seoanson\compute-performance-repo"
$labRoot = Join-Path $repoRoot "azure-compute-performance-operations-lab"
$lbName = az network lb list -g $rg --query "[0].name" -o tsv
$publicIpId = az network lb show -g $rg -n $lbName `
  --query "frontendIPConfigurations[?publicIPAddress].publicIPAddress.id | [0]" -o tsv
if (-not $publicIpId) {
  throw "No public IP is attached to the Load Balancer frontend."
}
$pip = az network public-ip show --ids $publicIpId --query ipAddress -o tsv
```

샘플 API를 설치·검증합니다.

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

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
