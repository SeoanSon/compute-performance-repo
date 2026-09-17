# 01. 준비하기

## 목표

Azure CLI와 PowerShell 세션을 준비하고 팀별 변수와 결과 디렉터리를 고정합니다.

## 이 단계에서 배우는 것

- Azure 리소스 작업에서 구독·지역·quota가 왜 첫 번째 운영 조건인지
- 팀별 리소스를 분리하고 만료 태그로 비용을 통제하는 방법
- 실습 결과를 명령 출력이 아니라 재현 가능한 파일로 남기는 습관

## 스스로 답할 질문

- quota가 충분하지 않으면 어떤 대안을 선택할 것인가?
- 같은 SKU라도 지역에 따라 배포 결과가 달라질 수 있는 이유는 무엇인가?
- 실습 종료 후 남은 리소스를 어떻게 식별할 것인가?

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
