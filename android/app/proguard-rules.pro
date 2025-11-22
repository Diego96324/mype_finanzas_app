# Flutter specific rules.
#
# This files is created by the Flutter tool and is required.
# See https://flutter.dev/docs/deployment/android#reviewing-the-build-configuration.
#
# If you have your own rules, you can add them here.
#
# This file is used by the Flutter tool when building AARs or app bundles.
# This file is not used when building an APK.
#
# Note:
#  - This file is provided as a sample since it's managed by the Flutter tool.
#  - You may need to add your own rules depending on your app's dependencies.
#  - If you are using native libraries, you may need to add rules for them.
#  - If you are using libraries that use reflection, you may need to add rules for them.

# Included by default in Flutter's AGP integration.
-dontwarn java.lang.invoke.*

# Keep rules for OkHttp
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
-dontwarn okhttp3.**
-dontwarn okio.**
