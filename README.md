# AI 사용량 바

![Claude Code와 Codex의 세션·주간 사용률을 표시하는 메뉴 막대](images/menu-bar.png)

macOS 메뉴 막대에서 Claude Code와 Codex 구독 사용량을 확인하는 작은 앱입니다. 각 서비스는 **세션 사용률 / 주간 사용률 / 주간 초기화까지 남은 시간** 순서로 표시합니다. 메뉴 막대를 클릭하면 초기화 시각과 마지막 갱신 시각을 확인할 수 있습니다.

## 다운로드 및 실행

1. [AI Usage Bar.zip 다운로드](https://github.com/gundolryan/Mac-AI-Usage-Bar/raw/refs/heads/main/downloads/AI-Usage-Bar.zip) 후 압축을 풉니다.
2. `AI Usage Bar.app`을 응용 프로그램 폴더로 옮겨 실행합니다. 메뉴 막대에 사용량이 나타납니다.
3. 앱은 Apple 개발자 서명 및 공증을 받지 않았습니다. macOS에서 실행을 막는 경우 앱의 출처를 확인한 뒤 시스템 설정의 개인정보 보호 및 보안에서 실행을 허용해야 할 수 있습니다.

앱은 Apple Silicon과 Intel Mac용 실행 파일을 함께 포함합니다. **사용량을 표시하려면** 이 Mac에 다음이 준비되어 있어야 합니다.

- `/usr/bin/python3` (없다면 Apple Command Line Tools 설치: `xcode-select --install`)
- Claude Code CLI와 Codex CLI 설치 및 각 구독 계정 로그인
- 각 서비스에서 사용량 한도를 제공하는 플랜

Claude Code는 터미널에서 `claude`, Codex는 `codex login`으로 로그인할 수 있습니다. 두 CLI가 Homebrew 경로 또는 `~/.local/bin`, `~/bin`, `~/.npm-global/bin`에 설치되어 있지 않은 경우, 앱에서 찾지 못할 수 있습니다. API 키나 일부 조직 계정에서는 구독 한도가 표시되지 않을 수 있습니다.

로그인 시 자동 실행하려면 macOS의 **시스템 설정 → 일반 → 로그인 항목**에 앱을 추가하세요.

## 소스에서 빌드

Apple Command Line Tools가 설치된 Mac에서 저장소를 내려받아 다음을 실행하세요.

```sh
./build.sh
open 'AI Usage Bar.app'
```

다시 빌드한 뒤에는 실행 중인 앱을 종료하고 다시 열어야 변경 사항이 적용됩니다.

Claude는 5분마다, Codex는 1분마다 새로고침합니다. 메뉴에서 **지금 새로고침**을 누르면 두 서비스 모두 즉시 다시 조회합니다. Claude 수치 뒤의 `!`는 수치가 한 시간 이상 갱신되지 않았다는 뜻입니다. 초기화 시간이 지났는데 새 데이터가 오지 않으면 `갱신 중`으로 표시합니다.

## 데이터와 제한

앱은 사용자의 컴퓨터에서 설치된 CLI를 실행하고 해당 CLI가 로그인된 계정의 사용량을 읽습니다. 대화 내용이나 인증 토큰을 앱이 수집하거나 별도 서버로 보내지 않습니다. 각 CLI는 사용량을 조회하기 위해 해당 서비스에 네트워크 요청을 보낼 수 있습니다.

Codex는 공식 app-server의 `account/rateLimits/read`를 사용합니다. Claude는 Claude Code의 실험적인 사용량 조회 인터페이스를 사용하므로 CLI 버전에 따라 작동이 바뀔 수 있습니다. 사용량은 계정과 플랜에 따라 제공 방식이 달라질 수 있습니다. 조회 실패 시 메뉴에 오류가 표시됩니다.

- [Codex app-server 문서](https://learn.chatgpt.com/docs/app-server)
- [Claude Code Remote Control 문서](https://code.claude.com/docs/en/remote-control)
