# 02. 배포하기

## 목표

워크숍용 VMSS, Load Balancer, Managed Disk, Log Analytics를 배포하고 샘플 API를 설치합니다.

## 이 단계에서 배우는 것

- 단일 VM보다 VMSS를 선택하는 운영상의 이유
- Load Balancer, backend pool, probe, VM 인스턴스의 관계
- Uniform orchestration이 이 워크숍의 기본 경로인 이유와 Flexible 환경의 차이
- 배포 성공과 애플리케이션 실행 성공을 분리해서 확인하는 방법

## 토폴로지

```text
Client → Public Load Balancer → Health Probe/Rule → VMSS instances → Order API
                                             └── Log Analytics / Monitor
```

## 스스로 답할 질문

- VMSS 인스턴스가 `Running`이어도 사용자가 접근하지 못할 수 있는 이유는 무엇인가?
- probe가 `/healthz`를 검사해야 하는 이유는 무엇인가?
- 샘플 API 설치 검증을 Load Balancer 테스트보다 먼저 해야 하는 이유는 무엇인가?

## 실행

전체 배포 명령은 [`../DEPLOYMENT.md`](../DEPLOYMENT.md)를 위에서부터 실행합니다.

중요: 신규 VMSS는 반드시 Uniform 모드로 배포합니다.

```powershell
az vmss create `
  --resource-group $rg `
  --name $vmss `
  --location $location `
  --orchestration-mode Uniform `
  --image Ubuntu2204 `
  --vm-sku Standard_D2s_v5 `
  --instance-count 2 `
  --lb-sku Standard `
  --backend-pool-name "${vmss}LBBackendPool" `
  --upgrade-policy-mode Rolling `
  --admin-username workshopadmin `
  --ssh-key-values "$HOME\.ssh\id_rsa.pub" `
  --vnet-name "vnet-compute-$team" `
  --subnet "snet-app"
```

배포 후 샘플 API는 수동 `run-command`가 아니라 helper로 설치합니다.

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

& (Join-Path $labRoot "scripts\Install-WorkshopApi.ps1") `
  -ResourceGroup $rg `
  -VmssName $vmss
```

## 통과 기준

```text
All VMSS instances passed the workshop API installation check.
```

## 다음 단계

[`../03-validate/README.md`](../03-validate/README.md)
