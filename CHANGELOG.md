# Changelog

<a href="#english"><img src="https://img.shields.io/badge/lang-English-blue.svg" alt="English"></a>
<a href="#한국어"><img src="https://img.shields.io/badge/lang-한국어-red.svg" alt="Korean"></a>

---

# English

All notable changes to this project will be documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.1.0] - 2026-04-28

### Added

- Claude Code project scaffold with hooks, skills, commands, agents, and test framework
- Bilingual architecture document (`docs/architecture.md`) with ASCII diagrams
- Developer onboarding guide (`docs/onboarding.md`)
- ADR and runbook templates for structured decision recording
- Secret scanning hook to block commits containing API keys or credentials
- Documentation sync hook to detect missing module CLAUDE.md files
- Session context hook to load project info at conversation start
- Harness test suite with 47 automated tests (`tests/run-all.sh`)
- Git commit-msg hook to auto-remove AI Co-Authored-By lines

### Changed

- **BREAKING:** Replace existing README.md with bilingual (English/Korean) version following shields.io badge conventions
- Update CLAUDE.md with project structure section and auto-sync rules

## [1.0.1] - 2026-04-08

### Added

- PowerPoint presentation (14 slides) with generator script for workshop delivery
- HTML presentation for Physical AI Workshop

### Changed

- Lighten presentation background for better projector visibility
- Replace Sim-to-Real ASCII pipeline with visual diagrams in Lab 6

## [1.0.0] - 2026-04-07

### Added

- Sim-to-Real deployment guide in Lab 6 with ANYmal-C architecture diagram
- HonKit workshop with 7 Labs and 3 Appendices covering full training pipeline
- GitBook integration for workshop content management

### Changed

- Upscale dashboard images to 2x resolution for larger display
- Replace ASCII architecture diagrams with PNG images for GitHub compatibility

## [0.1.0] - 2026-04-05

### Added

- Initial Terraform configuration for AWS GPU infrastructure (VPC, EC2 g6e.4xlarge, EBS, IAM, CloudWatch)
- EC2 bootstrap script (`user_data.sh`) with NGC login, Isaac Lab Docker build, and wrapper scripts
- PPO training pipeline for ANYmal-C rough terrain locomotion
- Trained policy models: TorchScript JIT (`policy_jit.pt`) and ONNX (`policy.onnx`)
- Play mode video recordings (10s test + 30s final)
- Chart.js training metrics dashboard (`isaac_lab_dashboard.html`)
- Comprehensive project report (`REPORT_Physical_AI_on_AWS.md`)
- Bilingual README with project documentation
- `.gitignore` with patterns for secrets, Terraform state, and build artifacts

[Unreleased]: https://github.com/comeddy/pai-sim-isaaclab/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/comeddy/pai-sim-isaaclab/compare/v1.0.1...v1.1.0
[1.0.1]: https://github.com/comeddy/pai-sim-isaaclab/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/comeddy/pai-sim-isaaclab/compare/v0.1.0...v1.0.0
[0.1.0]: https://github.com/comeddy/pai-sim-isaaclab/releases/tag/v0.1.0

---

# 한국어

이 프로젝트의 모든 주요 변경 사항은 이 파일에 기록됩니다.
이 문서는 [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)를 기반으로 하며,
[Semantic Versioning](https://semver.org/spec/v2.0.0.html)을 따릅니다.

## [Unreleased]

## [1.1.0] - 2026-04-28

### Added

- Claude Code 프로젝트 스캐폴드 추가 (hooks, skills, commands, agents, 테스트 프레임워크)
- 이중 언어 아키텍처 문서 (`docs/architecture.md`) ASCII 다이어그램 포함
- 개발자 온보딩 가이드 (`docs/onboarding.md`) 추가
- ADR 및 런북 템플릿 추가
- API 키/자격 증명 포함 커밋 차단을 위한 시크릿 스캐닝 hook 추가
- 모듈 CLAUDE.md 누락 감지를 위한 문서 동기화 hook 추가
- 대화 시작 시 프로젝트 정보를 로드하는 세션 컨텍스트 hook 추가
- 47개 자동화 테스트를 포함하는 harness 테스트 스위트 (`tests/run-all.sh`) 추가
- AI Co-Authored-By 자동 제거를 위한 Git commit-msg hook 추가

### Changed

- **BREAKING:** 기존 README.md를 shields.io 뱃지 규약을 따르는 이중 언어(영어/한국어) 버전으로 교체
- CLAUDE.md에 프로젝트 구조 섹션 및 자동 동기화 규칙 추가

## [1.0.1] - 2026-04-08

### Added

- 워크샵 발표용 PowerPoint 프레젠테이션 (14슬라이드) 및 생성 스크립트 추가
- Physical AI Workshop HTML 프레젠테이션 추가

### Changed

- 프로젝터 가시성 향상을 위한 프레젠테이션 배경색 밝게 변경
- Lab 6의 Sim-to-Real ASCII 파이프라인을 시각적 다이어그램으로 교체

## [1.0.0] - 2026-04-07

### Added

- Lab 6에 ANYmal-C 아키텍처 다이어그램 포함 Sim-to-Real 배포 가이드 추가
- 전체 훈련 파이프라인을 다루는 7개 Lab + 3개 부록 HonKit 워크샵 추가
- 워크샵 콘텐츠 관리를 위한 GitBook 통합

### Changed

- 대시보드 이미지를 2배 해상도로 업스케일
- GitHub 호환성을 위해 ASCII 아키텍처 다이어그램을 PNG 이미지로 교체

## [0.1.0] - 2026-04-05

### Added

- AWS GPU 인프라용 초기 Terraform 구성 (VPC, EC2 g6e.4xlarge, EBS, IAM, CloudWatch)
- NGC 로그인, Isaac Lab Docker 빌드, 래퍼 스크립트 포함 EC2 부트스트랩 스크립트 (`user_data.sh`)
- ANYmal-C 거친 지형 보행을 위한 PPO 훈련 파이프라인
- 학습된 정책 모델: TorchScript JIT (`policy_jit.pt`) 및 ONNX (`policy.onnx`)
- Play 모드 영상 녹화 (10초 테스트 + 30초 최종)
- Chart.js 훈련 메트릭 대시보드 (`isaac_lab_dashboard.html`)
- 종합 프로젝트 리포트 (`REPORT_Physical_AI_on_AWS.md`)
- 프로젝트 문서를 포함한 이중 언어 README
- 시크릿, Terraform 상태, 빌드 아티팩트 패턴을 포함한 `.gitignore`

[Unreleased]: https://github.com/comeddy/pai-sim-isaaclab/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/comeddy/pai-sim-isaaclab/compare/v1.0.1...v1.1.0
[1.0.1]: https://github.com/comeddy/pai-sim-isaaclab/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/comeddy/pai-sim-isaaclab/compare/v0.1.0...v1.0.0
[0.1.0]: https://github.com/comeddy/pai-sim-isaaclab/releases/tag/v0.1.0
