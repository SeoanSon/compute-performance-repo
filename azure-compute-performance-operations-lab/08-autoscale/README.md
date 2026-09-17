# 08. Autoscale 검증하기

## 목표

VMSS가 부하 증가에 반응하고, 새 인스턴스가 준비된 뒤 트래픽을 받으며, 부하 감소 후 안전하게 축소되는지 측정합니다.

## 이 단계에서 배우는 것

- Autoscale의 threshold, decision, provisioning, warm-up, recovery를 구분하는 방법
- CPU 기반 scaling이 latency 기반 문제를 항상 해결하지 못하는 이유
- scale-out과 비용, scale-in과 연결 종료 사이의 trade-off
- 배포와 autoscale이 동시에 발생할 때 보호해야 할 운영 조건

## 시간축으로 보기

```text
부하 증가 → threshold 초과 → scale decision → VM 준비
        → Ready/Health Probe 통과 → SLO 회복 → cool-down → scale-in
```

## 스스로 답할 질문

- 인스턴스가 늘었는데도 오류율이 계속 높다면 무엇을 의심할 것인가?
- warm-up 전에 트래픽을 받으면 어떤 장애가 생기는가?
- scale-in을 너무 빠르게 하면 어떤 요청이 영향을 받는가?

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
