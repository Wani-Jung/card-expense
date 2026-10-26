# google_mlkit_text_recognition 플러그인은 모든 언어 모델 클래스를 참조하지만 우리는 한국어 모델만 넣는다.
# 나머지(중국어·데바나가리·일본어)는 없어도 되므로 R8 경고만 끈다.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
