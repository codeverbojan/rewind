# Roadmap

The next work should improve measured playback reliability before broadening the platform surface. These are pending goals, not release promises.

1. **Reproducible source setup.** Separate portable policy tests from historical fixtures, document/generate authorized demo data, and provide a native dependency bootstrap with pinned inputs.
2. **Finish iPhone acceptance.** Verify first launch, compact layouts, rotation, source playback, captions, controls, storage and lifecycle on the actual phone.
3. **Reduce time to picture.** Profile source lookup, useful peer connections, verified buffering and decoder startup separately. Keep warm/cold cache results distinct and retain failed comparisons.
4. **Complete audio and subtitle acceptance.** Verify actual spoken language, track selection, text encodings, timing around seeks/stalls and semantic drift across real media.
5. **Improve discovery coverage.** Broader qualified shelves, stable suggestions, better ratings/metadata coverage for Kids, and clear handling of unavailable titles.
6. **Finish lifecycle and notification coverage.** Exercise interruption, background/foreground, repeated players, reminders and actual notification taps without losing profile state.
7. **Extract portable components.** Evaluate Android, Windows, macOS and Linux around a shared engine contract. Test LG webOS capability on a specific TV before committing to a port.

See [current evidence and limitations](status.md) and the [platform assessment](porting-assessment.md). Bug reports and focused contributions are welcome; start with [CONTRIBUTING](../CONTRIBUTING.md).
