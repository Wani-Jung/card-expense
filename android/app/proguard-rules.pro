# google_mlkit_text_recognition 플러그인은 모든 언어 모델 클래스를 참조하지만 우리는 한국어 모델만 넣는다.
# 나머지(중국어·데바나가리·일본어)는 없어도 되므로 R8 경고만 끈다.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**

# WorkManager(미분류 알림): Room 은 WorkDatabase_Impl 을 리플렉션으로 기본 생성자 호출해 만든다.
# room-runtime 규칙은 "-keep class * extends RoomDatabase" 뿐이라 R8 전체 모드에서 생성자가 지워지고,
# 앱 시작(InitializationProvider) 때 NoSuchMethodException 으로 바로 죽는다 (REQ-46).
-keep class * extends androidx.room.RoomDatabase { <init>(); }
