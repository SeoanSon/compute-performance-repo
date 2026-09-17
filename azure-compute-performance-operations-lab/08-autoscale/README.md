# 08. Autoscale 검증하기

## 목표

VMSS가 부하 증가에 반응하고, 새 인스턴스가 준비된 뒤 트래픽을 받으며, 부하 감소 후 안전하게 축소되는지 측정합니다.

## 확인

```powershell
az monitor autoscale show -g $rg -n "autoscale-$team" -o json
az vmss list-instances -g $rg -n $vmss -o table
```

스파이크 부하는 `05-load-test`의 HTTP 명령에서 `-Concurrency 64`로 실행합니다.

기록할 시각:

```text
threshold breach:
scale decision:
instance provisioned:
instance ready:
SLO recovered:
scale-in completed:
```

## 통과 기준

- scale decision latency 측정
- warm-up time 측정
- SLO breach duration 측정
- scale-in 중 오류율 1% 미만

## 다음 단계

[`../09-gameday/README.md`](../09-gameday/README.md)

