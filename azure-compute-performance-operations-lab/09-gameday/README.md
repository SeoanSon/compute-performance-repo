# 09. 장애 GameDay

## 목표

장애를 탐지하고, 영향을 좁히고, 복구를 검증하는 운영 절차를 연습합니다.

## Health Probe 장애

진행자 승인 후 테스트 VM에 실행합니다.

```powershell
$stop = "sudo systemctl stop order-api"
$start = "sudo systemctl start order-api"
az vmss run-command invoke -g $rg -n $vmss --instance-id 0 `
  --command-id RunShellScript --scripts $stop
curl.exe -v "http://$pip/healthz"
az vmss run-command invoke -g $rg -n $vmss --instance-id 0 `
  --command-id RunShellScript --scripts $start
```

## 타임라인

```text
탐지:
영향 범위:
초기 가설:
확인한 지표:
완화:
복구:
근본 원인:
재발 방지:
```

## 통과 기준

- 탐지·완화·복구 시각 기록
- 최소 2개 근거 지표 사용
- 복구를 HTTP 200 하나가 아니라 p95·오류율·Ready 인스턴스로 판정

## 다음 단계

[`../10-assessment/README.md`](../10-assessment/README.md)

