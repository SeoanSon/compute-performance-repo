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
