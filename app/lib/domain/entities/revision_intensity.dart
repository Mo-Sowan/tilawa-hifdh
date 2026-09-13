enum RevisionIntensity { light, focused, deep }

extension RevisionIntensityLabel on RevisionIntensity {
  String get label {
    switch (this) {
      case RevisionIntensity.light:
        return 'Light';
      case RevisionIntensity.focused:
        return 'Focused';
      case RevisionIntensity.deep:
        return 'Deep';
    }
  }
}
