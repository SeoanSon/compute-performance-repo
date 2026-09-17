# 배포 실습 가이드

이 문서는 워크숍용 Azure 환경을 팀별로 배포하고 검증하는 절차입니다. 모든 명령은 PowerShell 기준이며 Azure CLI 2.60 이상을 사용합니다.

## 1. 준비물

```powershell
az version
az login
az account set --subscription "<SUBSCRIPTION_ID_OR_NAME>"
az account show --query "{subscription:id,tenant:tenantId,user:user.name}" -o table
```

필수 권한:

- 리소스 그룹 생성 및 삭제
- VM/VMSS, Load Balancer, Managed Disk 생성
- Log Analytics Workspace 및 VM Insights 설정
- Monitor metric alert 생성

실습 전에 지역의 VM SKU quota를 확인합니다.

```powershell
$location = "koreacentral"
az vm list-usage --location $location `
  --query "[?contains(localName, 'DSv5') || contains(localName, 'FSv2')].{name:localName,current:currentValue,limit:limit}" `
  -o table
```

quota가 부족하면 인스턴스 수를 줄이거나 다른 지역·SKU를 선택합니다. quota가 충분해도 실제 지역 capacity가 보장되는 것은 아니므로, 배포 실패 시 대체 SKU를 준비합니다.

## 2. 팀별 변수와 리소스 그룹

팀마다 고유한 이름을 사용합니다. `expiresAt`은 실제 종료일로 바꿉니다.

```powershell
$team = "team01"
$location = "koreacentral"
$suffix = (Get-Random -Minimum 1000 -Maximum 9999)
$rg = "rg-compute-lab-$team"
$workspace = "law-compute-$team-$suffix"
$vmss = "vmss-order-$team"

az group create `
  --name $rg `
  --location $location `
  --tags workshop=azure-compute owner=$team expiresAt=2026-09-18
```

## 3. 기본 리소스 배포

실습 환경은 다음 구성으로 시작합니다.

- Ubuntu 기반 VMSS, 인스턴스 2개
- Standard Load Balancer와 HTTP probe
- Premium SSD 데이터 디스크
- Log Analytics Workspace
- VM Insights용 Azure Monitor Agent
- autoscale 최소 2, 기본 2, 최대 6

> 이 저장소에는 특정 구독의 VNet, 이미지, SKU를 고정한 템플릿을 넣지 않았습니다. 지역별 SKU·quota·네트워크 정책이 달라질 수 있으므로, 아래 명령으로 팀 환경을 명시적으로 만들고 결과를 기록합니다.

먼저 네트워크와 Log Analytics를 만듭니다.

```powershell
$vnet = "vnet-compute-$team"
$subnet = "snet-app"
$nsg = "nsg-app-$team"

az network nsg create -g $rg -n $nsg -l $location
az network vnet create -g $rg -n $vnet -l $location `
  --address-prefix 10.20.0.0/16 `
  --subnet-name $subnet `
  --subnet-prefix 10.20.1.0/24 `
  --network-security-group $nsg

az monitor log-analytics workspace create `
  --resource-group $rg `
  --workspace-name $workspace `
  --location $location `
  --retention-time 7

$workspaceId = az monitor log-analytics workspace show -g $rg -n $workspace `
  --query id -o tsv
```

SSH는 참가자 IP에서만 허용합니다. 공개 SSH가 필요하지 않으면 이 단계와 public IP를 생략합니다.

```powershell
$myIp = (Invoke-RestMethod -Uri "https://api.ipify.org")
az network nsg rule create -g $rg --nsg-name $nsg -n allow-ssh-workshop `
  --priority 100 --access Allow --protocol Tcp `
  --source-address-prefixes "$myIp/32" `
  --destination-port-ranges 22

az network nsg rule create -g $rg --nsg-name $nsg -n allow-http-workshop `
  --priority 110 --access Allow --protocol Tcp `
  --source-address-prefixes Internet `
  --destination-port-ranges 80
```

VMSS를 생성합니다.

```powershell
$adminUser = "workshopadmin"
$sshKey = "$HOME\.ssh\id_rsa.pub"

az vmss create `
  --resource-group $rg `
  --name $vmss `
  --location $location `
  --image Ubuntu2204 `
  --vm-sku Standard_D2s_v5 `
  --instance-count 2 `
  --data-disk-sizes-gb 32 `
  --storage-sku Premium_LRS `
  --upgrade-policy-mode Rolling `
  --admin-username $adminUser `
  --ssh-key-values $sshKey `
  --vnet-name $vnet `
  --subnet $subnet `
  --lb-sku Standard `
  --backend-pool-name "${vmss}LBBackendPool" `
  --tags workload=order-api workshop=azure-compute owner=$team
```

실제 운영형 실습에서는 `Standard_D2s_v5`를 기본값으로 사용하되, 지역에서 사용할 수 있는 SKU로 변경합니다. 변경한 SKU와 이유를 결과표에 기록합니다.

## 4. 샘플 HTTP 서비스 설치

VMSS 인스턴스에 설치 스크립트를 실행합니다. 샘플 서비스는 외부 의존성 없이 health endpoint와 부하 테스트용 endpoint를 제공합니다.

```powershell
$repoRoot = "C:\Users\seoanson\compute-performance-repo"
$scriptPath = Join-Path $repoRoot `
  "azure-compute-performance-operations-lab\scripts\install-order-api.sh"
if (-not (Test-Path -LiteralPath $scriptPath)) {
  throw "Install script not found: $scriptPath"
}
$installScript = Get-Content -Raw -LiteralPath $scriptPath

$orchestrationMode = az vmss show -g $rg -n $vmss `
  --query orchestrationMode -o tsv
if ($orchestrationMode -eq "Flexible") {
  # Flexible VMSS instances have resource-name IDs, not numeric instance IDs.
  # Use full resource IDs so names containing underscores are not parsed as
  # extra CLI arguments.
  $vmIds = @(
    az vm list -g $rg `
      --query "[?starts_with(name, '$vmss')].id" -o json |
      ConvertFrom-Json
  )
  if ($vmIds.Count -eq 0) {
    throw "No Flexible VMSS VMs found. Check `$rg and `$vmss."
  }
  foreach ($vmId in $vmIds) {
    az vm run-command invoke `
      --ids $vmId `
      --command-id RunShellScript `
      --scripts $installScript
  }
} else {
  $instanceIds = @(
    az vmss list-instances -g $rg -n $vmss `
      --query "[].instanceId" -o json |
      ConvertFrom-Json
  )
  if ($instanceIds.Count -eq 0) {
    throw "No VMSS instances found. Check `$rg and `$vmss."
  }
  foreach ($instanceId in $instanceIds) {
    if ($instanceId -notmatch '^\d+$') {
      throw "Unexpected Uniform VMSS instance ID: [$instanceId]"
    }
    az vmss run-command invoke `
      -g $rg -n $vmss `
      --instance-id $instanceId `
      --command-id RunShellScript `
      --scripts $installScript
  }
}
```

> `install-order-api.sh`는 워크숍 환경에서 사용할 샘플 서비스 설치 스크립트입니다. 실제 서비스 배포 방식(Docker, systemd, 패키지 배포)이 있다면 이 단계에서 교체하고 health endpoint 계약만 유지합니다.

## 5. Load Balancer probe와 HTTP rule 구성

`az vmss create` 버전이나 옵션 조합에 따라 backend pool만 만들어지고 HTTP probe/rule이 자동으로 만들어지지 않을 수 있습니다. 공인 IP가 있어도 rule이 없으면 외부에서 연결되지 않으므로 명시적으로 확인하고 없으면 생성합니다.

```powershell
$lbName = az network lb list -g $rg --query "[0].name" -o tsv
$frontendName = az network lb frontend-ip list -g $rg --lb-name $lbName `
  --query "[0].name" -o tsv
$backendName = az network lb address-pool list -g $rg --lb-name $lbName `
  --query "[0].name" -o tsv

$probeName = az network lb probe list -g $rg --lb-name $lbName `
  --query "[?port == '80'].name | [0]" -o tsv
if (-not $probeName) {
  $probeName = "order-api-health"
  az network lb probe create -g $rg --lb-name $lbName -n $probeName `
    --protocol Http --port 80 --path /healthz
}

# `az vmss create` normally creates a rule named `LBRule`. Reuse it rather
# than creating another rule with the same backend port and pool.
$ruleName = "LBRule"
az network lb rule show -g $rg --lb-name $lbName -n $ruleName `
  --query "{name:name,frontendPort:frontendPort,backendPort:backendPort,probe:probe.id,backendPool:backendAddressPool.id}" `
  -o json
az network lb rule update -g $rg --lb-name $lbName -n $ruleName `
  --probe-name $probeName

az network lb probe list -g $rg --lb-name $lbName `
  --query "[].{name:name,protocol:protocol,port:port,path:requestPath}" -o table
az network lb rule list -g $rg --lb-name $lbName `
  --query "[].{name:name,frontendPort:frontendPort,backendPort:backendPort,probe:probe.id}" -o table
```

Load Balancer frontend IP를 확인합니다.

```powershell
$pip = az network public-ip list -g $rg `
  --query "[?ipAddress != null].ipAddress | [0]" -o tsv
curl.exe "http://$pip/healthz"
curl.exe "http://$pip/readyz"
```

## 6. 연결 문제 진단

외부 curl이 실패하면 먼저 VM 내부에서 서비스가 실제로 실행 중인지 확인합니다.

```powershell
foreach ($vmId in $vmIds) {
  az vm run-command invoke --ids $vmId `
    --command-id RunShellScript `
    --scripts "systemctl is-active order-api; ss -lntp | grep ':80'; curl -fsS http://127.0.0.1/healthz"
}
```

정상 결과는 각 VM에서 `active`, `LISTEN ... :80`, `ok`입니다. 여기서 실패하면 설치 스크립트를 다시 실행하고, 외부 curl을 반복하지 않습니다.

VM 내부가 정상인데 외부 연결이 실패하면 다음을 확인합니다.

```powershell
az network lb show -g $rg -n $lbName `
  --query "{name:name,sku:sku.name,frontend:frontendIPConfigurations[].name,backend:backendAddressPools[].name}" -o json
az network lb rule list -g $rg --lb-name $lbName -o table
az network lb probe list -g $rg --lb-name $lbName -o table
az network nsg rule list -g $rg --nsg-name $nsg `
  --query "[].{name:name,priority:priority,access:access,direction:direction,port:destinationPortRange}" -o table
```

HTTP rule, HTTP probe, backend pool, 그리고 TCP 80 허용 NSG 규칙이 모두 있어야 합니다.

## 7. Azure Monitor 연결

VMSS에 system-assigned managed identity를 켭니다.

```powershell
az vmss identity assign -g $rg -n $vmss
$vmssId = az vmss show -g $rg -n $vmss --query id -o tsv
```

Azure Portal에서 다음을 연결합니다.

1. Monitor → Insights → Virtual machines → VM Insights
2. 대상 VMSS 선택
3. 앞에서 만든 Log Analytics Workspace 선택
4. 5~10분 뒤 `Heartbeat`, `Perf`, `InsightsMetrics` 데이터 확인

워크숍에서는 수집 지연을 고려해 기준선 측정 전에 최소 10분 기다립니다.

## 6. 배포 검증

다음 명령 결과를 `artifacts/deployment-verification.txt`에 저장합니다.

```powershell
New-Item -ItemType Directory -Force .\artifacts | Out-Null
az vmss show -g $rg -n $vmss `
  --query "{name:name,sku:sku.name,capacity:sku.capacity,upgrade:upgradePolicy.mode}" `
  -o json | Tee-Object .\artifacts\deployment-verification.txt

az vmss list-instances -g $rg -n $vmss `
  --query "[].{id:instanceId,provisioning:provisioningState,health:latestModelApplied}" `
  -o table | Tee-Object -Append .\artifacts\deployment-verification.txt
```

통과 조건:

- 인스턴스 2개가 `Succeeded`
- `/healthz`, `/readyz`가 HTTP 200
- Log Analytics에 인스턴스 heartbeat가 수집됨
- Load Balancer backend health가 정상

## 7. 비용이 커지는 실습 전환

실습 중에만 최대 인스턴스 수를 6으로 설정합니다.

```powershell
az monitor autoscale create -g $rg -n "autoscale-$team" `
  --resource $vmssId --min-count 2 --max-count 6 --count 2

az monitor autoscale rule create -g $rg `
  --autoscale-name "autoscale-$team" `
  --condition "Percentage CPU > 70 avg 5m" `
  --scale out 1

az monitor autoscale rule create -g $rg `
  --autoscale-name "autoscale-$team" `
  --condition "Percentage CPU < 35 avg 10m" `
  --scale in 1
```

실습이 끝나면 반드시 autoscale과 VMSS를 삭제합니다.

```powershell
az group delete --name $rg --yes --no-wait
```
