
# WorkManager(미분류 알림): Room 은 WorkDatabase_Impl 을 리플렉션으로 기본 생성자 호출해 만든다.
# room-runtime 규칙은 "-keep class * extends RoomDatabase" 뿐이라 R8 전체 모드에서 생성자가 지워지고,
# 앱 시작(InitializationProvider) 때 NoSuchMethodException 으로 바로 죽는다 (REQ-46).
-keep class * extends androidx.room.RoomDatabase { <init>(); }
