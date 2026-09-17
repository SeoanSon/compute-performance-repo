# Azure Compute Performance & Operations Lab

Azure VM/VMSS를 실제 운영 관점에서 배포하고, 관측하고, 부하를 주고, 병목을 분석하고, 튜닝하는 단계형 핸즈온 워크숍입니다.

## 시작하기

### 이미 Azure 리소스를 배포했다면

`00-start/README.md`부터 시작하세요.

### 아직 배포하지 않았다면

아래 순서를 그대로 따라갑니다.

```text
00-start       워크숍 목표와 실습 상태 확인
01-prepare     도구·변수·구독 준비
02-deploy      VMSS·Load Balancer·샘플 API 배포
03-validate    배포 완료 후 API와 네트워크 검증
04-baseline    정상 상태 기준선 측정
05-load-test   CPU·메모리·디스크·HTTP 부하 실행
06-analyze     KQL과 Before/After 결과 분석
07-tune        SKU·Managed Disk 변경 의사결정
08-autoscale   VMSS Autoscale·Rolling Upgrade 검증
09-gameday     장애 주입과 복구
10-assessment  학습 전후 평가와 최종 산출물
99-cleanup     결과 보존과 리소스 정리
```

각 단계는 다음 네 가지를 고정된 형식으로 제공합니다.

- **목표**: 이번 단계에서 이해할 운영 개념
- **실행**: 복사·붙여넣기 가능한 명령
- **통과 기준**: 다음 단계로 넘어갈 조건
- **다음 단계**: 이어서 열 문서

## 단계별 학습 지도

| 단계 | 배우는 핵심 내용 | 최종 질문 |
|---|---|---|
| `00-start` | 운영형 Compute 문제를 보는 관점 | 이번 실습에서 무엇을 측정하고 증명할 것인가? |
| `01-prepare` | 구독·quota·실습 변수 관리 | 이 환경에서 안전하게 실험할 수 있는가? |
| `02-deploy` | VMSS 기반 운영 토폴로지 | 서비스가 확장 가능한 형태로 배포되었는가? |
| `03-validate` | Health Probe·backend·네트워크 경로 | 사용자가 실제로 서비스에 도달할 수 있는가? |
| `04-baseline` | 정상 상태와 SLO 기준선 | 정상과 비정상을 어떤 숫자로 구분할 것인가? |
| `05-load-test` | 재현 가능한 부하와 병목 후보 | 어떤 부하에서 어떤 자원이 먼저 한계에 도달하는가? |
| `06-analyze` | KQL·시간 상관관계·원인 분석 | 관찰된 현상의 가장 강한 증거는 무엇인가? |
| `07-tune` | SKU·디스크·비용 trade-off | 어떤 변경이 가장 적은 위험으로 효과를 내는가? |
| `08-autoscale` | 확장 지연·warm-up·scale-in | 자동 확장이 SLO를 실제로 보호하는가? |
| `09-gameday` | 장애 탐지·완화·복구 | 제한된 시간 안에 서비스를 어떻게 회복할 것인가? |
| `10-assessment` | 역량과 결과의 전후 비교 | 워크숍 전보다 운영 판단이 좋아졌는가? |
| `99-cleanup` | 결과 보존·비용·환경 정리 | 실습 결과를 남기고 안전하게 종료했는가? |

## 이 워크숍의 최종 결과

참가자는 마지막에 “VM을 생성할 수 있다”가 아니라 다음을 설명할 수 있어야 합니다.

> “이 서비스의 병목은 무엇이며, 어떤 지표로 확인했고, 어떤 변경을 적용했으며, SLO와 비용이 어떻게 달라졌는가?”

## 실습 결과물

```text
artifacts/
  deployment/
  baseline/
  load-tests/
  analysis.md
  tuning-decision.md
  incident-timeline.md
```

## 문서 지도

| 문서 | 용도 |
|---|---|
| `DEPLOYMENT.md` | 배포 명령의 상세 레퍼런스 |
| `RUNBOOK.md` | 기존 환경의 전체 실행 런북 |
| `TESTING-AND-ANALYSIS.md` | 테스트·KQL·분석 레퍼런스 |
| `ASSESSMENT.md` | 사전·사후 평가와 채점 |
| `FACILITATOR-GUIDE.md` | 진행자용 운영 가이드 |
| `scripts/Install-WorkshopApi.ps1` | VMSS 인스턴스에 샘플 API 설치·검증 |

단계 폴더가 참가자의 기본 경로이고, 위 문서는 필요한 경우에만 참고합니다.
