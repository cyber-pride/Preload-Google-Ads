# Fix for WorkManager crash in release mode (used by google_mobile_ads)
-keep class androidx.work.impl.** { *; }
-dontwarn androidx.work.impl.**
