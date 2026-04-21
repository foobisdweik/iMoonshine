import AppIntents

/// Marks the SwiftPM library target as the package that owns iMoonshine's
/// App Intents so app/extension builds can include package-defined metadata.
public struct iMoonshineIntentsPackage: AppIntentsPackage {}
