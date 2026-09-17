# 09. 장애 GameDay

## 목표

장애를 탐지하고, 영향을 좁히고, 복구를 검증하는 운영 절차를 연습합니다.

## 이 단계에서 배우는 것

- 장애 대응에서 탐지·완화·복구·근본원인을 분리하는 방법
- 서비스 복구 전에 증거와 타임라인을 보존하는 이유
- Health Probe 장애가 애플리케이션 장애와 다르게 보이는 방식
- “HTTP 200 한 번”이 아니라 일정 시간의 안정성으로 복구를 선언하는 방법

## 운영자 역할

```text
탐지자: 무엇이 깨졌는가?
분석자: 어디까지 영향을 받았는가?
완화자: 어떻게 영향 범위를 줄이는가?
기록자: 어떤 증거와 시간을 남기는가?
```

## 스스로 답할 질문

- 지금 추가 변경을 멈춰야 하는가, 완화를 먼저 해야 하는가?
- 복구되었다고 선언할 측정값과 지속 시간은 무엇인가?
- 같은 장애가 다시 발생하지 않게 자동화할 수 있는 것은 무엇인가?

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
