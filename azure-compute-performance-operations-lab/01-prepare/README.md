# 01. 준비하기

## 목표

Azure CLI와 PowerShell 세션을 준비하고 팀별 변수와 결과 디렉터리를 고정합니다.

## 실행

```powershell
az login
az account set --subscription "<SUBSCRIPTION_ID_OR_NAME>"
az account show --query "{subscription:id,tenant:tenantId,user:user.name}" -o table
az version

$team = "team01"
$location = "koreacentral"
$rg = "rg-compute-lab-$team"
$vmss = "vmss-order-$team"
$repoRoot = "C:\Users\seoanson\compute-performance-repo"
$labRoot = Join-Path $repoRoot "azure-compute-performance-operations-lab"
$artifacts = Join-Path $labRoot "artifacts"
New-Item -ItemType Directory -Force $artifacts | Out-Null

az vm list-usage --location $location `
  --query "[?contains(localName, 'DSv5')].{name:localName,current:currentValue,limit:limit}" -o table
```

`team`, `location`, `subscription`만 자신의 환경에 맞게 바꿉니다.

## 통과 기준

- 올바른 구독이 선택됨
- VM SKU quota가 인스턴스 2개를 수용함
- `$rg`, `$vmss`, `$labRoot`가 출력됨

## 다음 단계

신규 환경은 [`../02-deploy/README.md`](../02-deploy/README.md), 이미 배포했다면 [`../03-validate/README.md`](../03-validate/README.md)로 이동합니다.

