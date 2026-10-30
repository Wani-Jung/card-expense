# Play App Signing 에 지금 키스토어 등록하기 (PEPK 내보내기 절차)

목적: 플레이스토어판도 깃허브판과 **같은 서명 키**로 배포되게 한다. 그래야 깃허브판(APK) 사용자가 데이터를 유지한 채 스토어판으로 덮어 설치할 수 있다 (applicationId `com.wani.card_expense` 와 서명 키가 모두 같아야 함).

> 지금은 준비 문서만. 실제 실행은 Play Console 에서 `encryption_public_key.pem` 을 내려받아 `Downloads` 폴더에 둔 뒤 따로 요청할 때 한다.

## 절대 커밋하지 않는 것

키스토어(`*.jks`), 비밀번호(`android/key.properties`), Play 암호화 공개키(`*.pem`), PEPK 도구(`pepk.jar`), 결과 zip.
루트 `.gitignore` 와 `android/.gitignore` 에 걸려 있다. 아래 명령은 모두 **레포 밖**(`Downloads`, 키스토어 폴더)에서만 파일을 만든다.

## 필요한 것

| 무엇 | 어디 |
|---|---|
| 키스토어 | `C:\Users\EKR\Documents\card_expense_keystore\card_expense.jks` |
| 키 별칭(alias) | `card_expense` (`android/key.properties` 의 `keyAlias`) |
| 키스토어·키 비밀번호 | `android/key.properties` (화면에 띄우지 말고 PEPK 가 물을 때 직접 입력) |
| Java 17 | 이미 설치됨: `C:\Program Files\Microsoft\jdk-17.0.20.8-hotspot\bin\java.exe` |
| `pepk.jar` | Play Console 화면의 'PEPK 도구 다운로드' 링크 → `Downloads\pepk.jar` |
| `encryption_public_key.pem` | Play Console 화면의 '암호화 공개 키 다운로드' → `Downloads\encryption_public_key.pem` |

## 1. Play Console 에서 화면 열기

1. Play Console → 앱(공감카드 관리) → **테스트 및 출시 → 앱 무결성 → Play 앱 서명** (첫 AAB 업로드 전이면 첫 버전 만들기 화면의 '앱 서명 키 선택'에서).
2. **앱 서명 키 변경/선택 → 'Java 키 저장소에서 키 내보내기 및 업로드'** 를 고른다.
   ('Google 에서 생성한 키 사용'을 고르면 깃허브판과 키가 달라져 덮어쓰기 설치가 안 되므로 고르지 말 것)
3. 그 화면에서 `pepk.jar` 와 `encryption_public_key.pem` 을 내려받아 `Downloads` 에 둔다.

## 2. 키 내보내기 (PowerShell)

```powershell
cd $env:USERPROFILE\Downloads
& "C:\Program Files\Microsoft\jdk-17.0.20.8-hotspot\bin\java.exe" -jar pepk.jar `
  --keystore="C:\Users\EKR\Documents\card_expense_keystore\card_expense.jks" `
  --alias=card_expense `
  --output="$env:USERPROFILE\Downloads\card_expense_play_signing.zip" `
  --include-cert `
  --rsa-aes-encryption `
  --encryption-key-path="$env:USERPROFILE\Downloads\encryption_public_key.pem"
```

- 키스토어 비밀번호와 키 비밀번호를 차례로 묻는다. 직접 입력한다 (명령줄 인자로 넣지 않음 → 기록에 안 남음).
- Play Console 이 보여 주는 명령의 옵션이 위와 다르면 **Console 화면의 명령을 따른다** (도구 버전에 따라 옵션이 바뀔 수 있음). 경로만 위 표대로 바꿔 넣는다.

**결과 zip 위치:** `C:\Users\EKR\Downloads\card_expense_play_signing.zip`

## 3. 업로드

1. 같은 Play Console 화면에서 결과 zip(`card_expense_play_signing.zip`)을 업로드하고 저장한다.
2. 업로드 키: CI 가 AAB 를 같은 키스토어로 서명하므로 지금 키가 업로드 키 역할도 한다. Console 이 업로드 키 인증서를 따로 요구하면 아래로 만든 PEM 을 올린다.

```powershell
& "C:\Program Files\Microsoft\jdk-17.0.20.8-hotspot\bin\keytool.exe" -export -rfc `
  -keystore "C:\Users\EKR\Documents\card_expense_keystore\card_expense.jks" `
  -alias card_expense `
  -file "$env:USERPROFILE\Downloads\upload_certificate.pem"
```

## 4. 확인

- Play Console 앱 서명 화면의 **앱 서명 키 인증서 SHA-256** 이 지금 키와 같은지 본다:

```powershell
& "C:\Program Files\Microsoft\jdk-17.0.20.8-hotspot\bin\keytool.exe" -list -v `
  -keystore "C:\Users\EKR\Documents\card_expense_keystore\card_expense.jks" -alias card_expense
```

  출력의 `SHA256:` 값 = Console 의 '앱 서명 키 인증서' SHA-256 이어야 한다.

## 5. 정리

- 업로드가 끝나면 `Downloads` 의 `card_expense_play_signing.zip`, `encryption_public_key.pem`, `upload_certificate.pem`, `pepk.jar` 를 지운다 (키 원본은 키스토어 폴더에만).
- 레포에서 `git status` 로 위 파일이 하나도 보이지 않는지 확인한다.
