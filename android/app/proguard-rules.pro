# Proguard rules for VaultETH
-keep class org.bouncycastle.** { *; }
-dontwarn org.bouncycastle.**
-keep class com.vaulteth.app.core.Models** { *; }
-keepclassmembers class * implements java.io.Serializable { *; }
