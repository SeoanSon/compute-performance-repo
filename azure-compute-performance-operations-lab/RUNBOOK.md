# 워크숍 실행 런북

이 문서는 **배포가 끝난 뒤부터 종료까지** 참가자가 순서대로 실행하는 단일 경로입니다. 각 단계의 명령을 위에서부터 복사해 PowerShell에 붙여 넣고, 통과 조건을 확인한 뒤 다음 단계로 이동합니다.

> 현재 이미 배포를 완료했다면 **1단계부터** 시작합니다. 명령은 Windows PowerShell 5.1에서도 동작하도록 작성했습니다.

## 전체 흐름

```text
1. 세션 복구 및 변수 설정
   ↓
2. 배포 상태 확인
   ↓
3. API 내부/외부 연결 확인
   ↓
4. Azure Monitor 수집 확인
   ↓
5. 기준선 테스트 실행
   ↓
6. CPU 부하 테스트 실행
   ↓
7. 결과 분석 및 병목 가설 작성
   ↓
8. VMSS Autoscale 검증
   ↓
9. 장애 주입 GameDay
   ↓
10. 결과 제출 및 리소스 삭제
```

## 1. 세션 복구 및 변수 설정

PowerShell을 새로 열었거나 `$rg`, `$vmss`가 사라진 경우 아래 블록을 실행합니다. 본인의 팀 값만 바꿉니다.

```powershell
$team = "team01"
$rg = "rg-compute-lab-$team"
$vmss = "vmss-order-$team"
$repoRoot = "C:\Users\seoanson\compute-performance-repo"
$labRoot = Join-Path $repoRoot "azure-compute-performance-operations-lab"
$artifacts = Join-Path $labRoot "artifacts"

New-Item -ItemType Directory -Force `
  (Join-Path $artifacts "load-tests"), `
  (Join-Path $artifacts "screenshots") | Out-Null

az group show -n $rg --query "{name:name,location:location,state:properties.provisioningState}" -o table
az vmss show -g $rg -n $vmss `
  --query "{name:name,sku:sku.name,capacity:sku.capacity,mode:orchestrationMode}" -o table
```

두 명령이 정상적으로 리소스 그룹과 VMSS 정보를 출력해야 합니다.

## 2. 배포 상태 확인

```powershell
$lbName = az network lb list -g $rg --query "[0].name" -o tsv
$frontendConfigs = @(
  az network lb frontend-ip list -g $rg --lb-name $lbName -o json |
    ConvertFrom-Json
)
$publicIpId = $null
foreach ($frontendConfig in $frontendConfigs) {
  if ($null -ne $frontendConfig.publicIPAddress -and $frontendConfig.publicIPAddress.id) {
    $publicIpId = $frontendConfig.publicIPAddress.id
    break
  }
}
$pip = $null
if ($publicIpId) {
  $pip = az network public-ip show --ids $publicIpId --query ipAddress -o tsv
}

$vmssMode = az vmss show -g $rg -n $vmss --query orchestrationMode -o tsv
$vmssMode
$lbName
$publicIpId
$pip

if (-not $lbName) { throw "Load Balancer was not found." }
if (-not $pip) {
  Write-Host "No public IP is attached. Frontend configuration:"
  $frontendConfigs | Select-Object name, privateIPAddress, publicIPAddress | Format-List
  throw "No public IP is attached to the Load Balancer frontend. Run the remediation block below."
}
```

If the previous block says that no public IP is attached, run this remediation block and then repeat step 2.

```powershell
$frontendName = $frontendConfigs[0].name
$pipName = "pip-$vmss"

az network public-ip create -g $rg -n $pipName `
  --sku Standard `
  --allocation-method Static `
  --dns-name $vmss.ToLower()

az network lb frontend-ip update -g $rg `
  --lb-name $lbName `
  -n $frontendName `
  --public-ip-address $pipName
```

인스턴스 상태를 확인합니다.

```powershell
if ($vmssMode -eq "Flexible") {
  $vmIds = @(
    az vm list -g $rg `
      --query "[?starts_with(name, '$vmss')].id" -o json |
      ConvertFrom-Json
  )
  $vmIds | ForEach-Object { az resource show --ids $_ --query "{name:name,state:properties.provisioningState}" -o table }
} else {
  az vmss list-instances -g $rg -n $vmss `
    --query "[].{instance:instanceId,state:provisioningState}" -o table
}
```

## 3. API와 Load Balancer 확인

### 3-1. VM 내부 확인

Flexible VMSS라면 다음을 그대로 실행합니다.

```powershell
$scriptPath = Join-Path $labRoot "scripts\install-order-api.sh"
$installScript = Get-Content -Raw -LiteralPath $scriptPath
if ($installScript -notmatch "order-api.service") {
  throw "The local install script is not the expected workshop script: $scriptPath"
}

if ($vmssMode -eq "Flexible") {
  foreach ($vmId in $vmIds) {
    az vm run-command invoke --ids $vmId `
      --command-id RunShellScript `
      --scripts "systemctl is-active order-api; ss -lntp | grep ':80'; curl -fsS http://127.0.0.1/healthz"
  }
}
```

각 VM에서 다음이 보여야 합니다.

```text
active
LISTEN ... :80
ok
```

`inactive`이고 80번 포트의 프로세스가 `nginx`이면 이미지에 포함된 nginx가
샘플 API의 포트를 점유한 상태입니다. 아래 재설치 블록은 nginx를 중지하고
`order-api`를 다시 시작합니다.

`active` 또는 `ok`가 없으면 다음 설치 블록을 한 번 실행한 뒤 3-1을 다시 실행합니다.

```powershell
if ($vmssMode -eq "Flexible") {
  foreach ($vmId in $vmIds) {
    $result = az vm run-command invoke --ids $vmId `
      --command-id RunShellScript `
      --scripts $installScript | ConvertFrom-Json
    $result.value[0].message
  }
} else {
  $instanceIds = @(az vmss list-instances -g $rg -n $vmss --query "[].instanceId" -o json | ConvertFrom-Json)
  foreach ($instanceId in $instanceIds) {
    $result = az vmss run-command invoke -g $rg -n $vmss --instance-id $instanceId `
      --command-id RunShellScript --scripts $installScript | ConvertFrom-Json
    $result.value[0].message
  }
}
```

### 3-2. Load Balancer rule과 probe 확인

```powershell
az network lb probe list -g $rg --lb-name $lbName `
  --query "[].{name:name,protocol:protocol,port:port,path:requestPath}" -o table

az network lb rule list -g $rg --lb-name $lbName `
  --query "[].{name:name,frontend:frontendPort,backend:backendPort,probe:probe.id}" -o table

az network lb rule update -g $rg --lb-name $lbName -n LBRule `
  --probe-name order-api-health
```

`order-api-health`, port `80`, path `/healthz`, `LBRule`이 있어야 합니다. 기존 rule이 이미 존재하면 새 rule을 만들지 않습니다.

### 3-3. 외부 연결 확인

```powershell
curl.exe -fsS "http://$pip/healthz"
curl.exe -fsS "http://$pip/readyz"
curl.exe -fsS "http://$pip/api/orders"
```

세 명령이 HTTP 200 응답을 반환해야 합니다. 여기서 실패하면 부하 테스트로 넘어가지 말고 [`DEPLOYMENT.md`](./DEPLOYMENT.md)의 연결 문제 진단을 수행합니다.

## 4. Azure Monitor 수집 확인

```powershell
$workspace = az monitor log-analytics workspace list -g $rg --query "[0].name" -o tsv
$workspaceId = az monitor log-analytics workspace show -g $rg -n $workspace --query customerId -o tsv
$workspace
$workspaceId

az vmss show -g $rg -n $vmss `
  --query "{identity:identity.type,principalId:identity.principalId}" -o json
```

Azure Portal에서 `Monitor > Logs`로 이동해 해당 Workspace를 선택하고 다음 쿼리를 실행합니다.

```kusto
Heartbeat
| where TimeGenerated > ago(15m)
| summarize lastSeen=max(TimeGenerated), samples=count() by Computer
| order by Computer asc
```

VMSS의 모든 인스턴스가 최근 15분 안에 보이면 통과입니다. 데이터가 없으면 아직 수집 에이전트가 연결되지 않은 것이므로 다음 단계로 진행하지 않습니다.

데이터가 없을 때는 Azure Portal에서 `Monitor > Insights > Virtual machines`로 이동해 대상 VMSS의 **Enable monitoring**을 선택하고 위 Workspace를 연결합니다. 연결 후 5~10분 기다린 다음 같은 쿼리를 다시 실행합니다. 이 워크숍에서는 기준선 숫자만 먼저 수집할 수 있지만, 플랫폼 지표가 없으면 병목 원인 분석은 완료로 인정하지 않습니다.

## 5. 기준선 테스트

추가 도구 설치 없이 저장소의 PowerShell 스크립트를 실행합니다.

```powershell
$runId = Get-Date -Format "yyyyMMdd-HHmmss"
$target = "http://$pip/api/orders"
$result = Join-Path $artifacts "load-tests\baseline-$runId.csv"

& (Join-Path $labRoot "scripts\http-baseline.ps1") `
  -TargetUrl $target `
  -DurationSeconds 60 `
  -Concurrency 8 `
  -OutputPath $result

Get-Content "$result.summary.json" | ConvertFrom-Json | Format-List
```

판정:

- `SuccessRate`가 99.5% 이상
- `P95Ms`가 250ms 이하
- `RequestsPerSecond`와 `P95Ms`를 `baseline.csv`에 기록

동일한 명령을 한 번 더 실행해 결과 편차를 확인합니다. 두 실행 결과의 p95 차이가 20%보다 크면 네트워크나 환경이 안정되지 않은 것이므로 기준선으로 채택하지 않습니다.

## 6. CPU 부하 테스트

먼저 기준선 결과 파일을 보존한 상태에서 한 VM에만 CPU 부하를 줍니다.

```powershell
$cpuScript = "sudo apt-get update -y && sudo apt-get install -y stress-ng && stress-ng --cpu 4 --timeout 120s --metrics-brief"
if ($vmssMode -eq "Flexible") {
  $cpuVm = $vmIds[0]
  az vm run-command invoke --ids $cpuVm `
    --command-id RunShellScript `
    --scripts $cpuScript
} else {
  az vmss run-command invoke -g $rg -n $vmss --instance-id 0 `
    --command-id RunShellScript `
    --scripts $cpuScript
}
```

부하 명령이 실행되는 동안 다른 PowerShell 창에서 API 테스트를 실행합니다.

```powershell
$runId = Get-Date -Format "yyyyMMdd-HHmmss"
$result = Join-Path $artifacts "load-tests\cpu-$runId.csv"
& (Join-Path $labRoot "scripts\http-baseline.ps1") `
  -TargetUrl $target `
  -DurationSeconds 120 `
  -Concurrency 8 `
  -OutputPath $result
Import-Csv $result | Format-Table
```

기준선 파일과 CPU 부하 파일의 `P95Ms`, `SuccessRate`를 비교하고, 같은 시간 범위의 CPU 지표를 Log Analytics에서 조회합니다.

## 7. 결과 분석

각 테스트 후 아래 템플릿을 복사해 `artifacts\analysis.md`에 작성합니다.

```text
테스트:
시작/종료(UTC):
부하 조건:
변경 사항:

Before:
- RPS:
- P95:
- 성공률:
- CPU:

After:
- RPS:
- P95:
- 성공률:
- CPU:

관찰한 사용자 영향:
상관관계가 있는 플랫폼 지표 2개:
가설:
반증 또는 추가 확인:
다음 검증:
```

분석은 [`TESTING-AND-ANALYSIS.md`](./TESTING-AND-ANALYSIS.md)의 KQL 쿼리를 사용합니다. 숫자 없는 “느려졌다/개선됐다” 결론은 인정하지 않습니다.

## 8. 다음 실습으로 이동

| 완료 조건 | 다음 단계 |
|---|---|
| 외부 health/API 200 | 기준선 테스트 |
| 기준선 2회 결과 편차 20% 이하 | CPU·디스크 부하 |
| Before/After 파일과 분석 문서 생성 | SKU 또는 디스크 튜닝 |
| Autoscale 정책 확인 | 스파이크 테스트 |
| 장애 타임라인 작성 | 최종 평가 |

Autoscale과 스파이크 테스트는 [`TESTING-AND-ANALYSIS.md`](./TESTING-AND-ANALYSIS.md) 8장을, 장애 주입은 10장을 실행합니다.

## 9. 제출과 정리

```powershell
Get-ChildItem $artifacts -Recurse | Select-Object FullName,Length

az vmss list-instances -g $rg -n $vmss -o json |
  Set-Content (Join-Path $artifacts "final-vmss-state.json")
```

제출 파일:

- `artifacts\load-tests\baseline-*.csv`
- `artifacts\load-tests\cpu-*.csv`
- `artifacts\analysis.md`
- `artifacts\tuning-decision.md`
- `artifacts\incident-timeline.md`

모든 결과를 확인한 뒤에만 삭제합니다.

```powershell
az group delete -n $rg --yes --no-wait
```
