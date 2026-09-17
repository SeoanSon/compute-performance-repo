# 00. 시작하기

## 목표

이번 워크숍에서는 VM을 만드는 방법이 아니라 다음 운영 사이클을 수행합니다.

```text
배포 → 검증 → 기준선 → 부하 → 분석 → 튜닝 → 확장 → 장애 대응
```

## 현재 상태별 시작점

| 현재 상태 | 다음 문서 |
|---|---|
| Azure CLI·구독만 준비됨 | `01-prepare/README.md` |
| VMSS 배포 전 | `02-deploy/README.md` |
| VMSS 배포 완료 | `03-validate/README.md` |
| `/healthz`가 200 | `04-baseline/README.md` |
| 기준선 CSV가 있음 | `05-load-test/README.md` |

## 규칙

1. 단계 순서를 건너뛰지 않습니다.
2. 통과 기준을 만족하기 전에는 다음 단계로 이동하지 않습니다.
3. 모든 결과는 `artifacts`에 저장합니다.
4. `Install-WorkshopApi.ps1`가 실패하면 Load Balancer나 부하 테스트를 디버깅하지 않습니다.

## 다음 단계

배포하지 않았다면 [`../01-prepare/README.md`](../01-prepare/README.md), 배포했다면 [`../03-validate/README.md`](../03-validate/README.md)를 엽니다.

