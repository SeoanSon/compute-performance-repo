# 02. 배포하기

## 목표

워크숍용 VMSS, Load Balancer, Managed Disk, Log Analytics를 배포하고 샘플 API를 설치합니다.

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

