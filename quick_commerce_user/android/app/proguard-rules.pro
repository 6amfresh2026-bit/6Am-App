# Flutter's engine is reached reflectively from native code; R8 cannot see those
# references and would strip them.
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Razorpay's checkout is invoked reflectively and ships its own annotations.
-keep class com.razorpay.** { *; }
-keepclassmembers class * { @com.razorpay.* <methods>; }
-dontwarn com.razorpay.**

# Model classes are deserialized from JSON by name.
-keepattributes Signature, *Annotation*, EnclosingMethod, InnerClasses
