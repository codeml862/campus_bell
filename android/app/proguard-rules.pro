# flutter_local_notifications stores notification details with Gson;
# keep its classes so scheduled/shown notifications don't break after R8.
-keep class com.dexterous.** { *; }
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keepattributes Signature
