"""Generate Rewind's original, sample-free profile cues (Python stdlib only)."""
from pathlib import Path
import math
import struct
import wave

RATE = 32000
DEST = Path(__file__).parent / "Resources/Rewind/Sounds"


def write(name, duration, signal):
    samples = [signal(i / RATE, duration) for i in range(round(duration * RATE))]
    peak = max(abs(v) for v in samples)
    pcm = [round(v / max(peak, 1e-9) * 0.48 * 32767) for v in samples]
    # Exact silent boundaries prevent edit clicks; no dependency on a codec.
    pcm[0] = pcm[-1] = 0
    with wave.open(str(DEST / name), "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(struct.pack("<" + "h" * len(pcm), *pcm))


def arrival(t, duration):
    # Original two-impact sonic mark. Low fundamentals plus audible harmonics
    # give the old iPad's small speakers weight without relying on sub-bass.
    value = 0
    noise = sum(math.sin(2 * math.pi * f * t) for f in (2347, 3953, 5171)) / 3
    for start, gain, frequency, decay in ((.015, .64, 146.83, .115), (.245, 1, 73.416, .30)):
        u = t - start
        if u < 0:
            continue
        envelope = (1 - math.exp(-u / .0025)) * math.exp(-u / decay)
        bend = 32 * .014 * (1 - math.exp(-u / .014))
        harmonics = sum(a * math.sin(2 * math.pi * (frequency * n * u + bend))
                        for n, a in ((1, .35), (2, .46), (3, .21), (4, .10)))
        value += gain * (envelope * harmonics + noise * math.exp(-u / .013) * .14)
    u = max(0, t - .26)
    value += .06 * (1 - math.exp(-u / .035)) * math.exp(-u / .32) * (
        math.sin(2 * math.pi * 220 * u) + .5 * math.sin(2 * math.pi * 293.66 * u))
    return value * min(1, max(0, (duration - t) / .1))


def selection(t, duration):
    envelope = (1 - math.exp(-t / .003)) * math.exp(-t / .024) * min(1, (duration - t) / .02)
    return envelope * (math.sin(2 * math.pi * 587.33 * t) + .12 * math.sin(2 * math.pi * 1174.66 * t))


def regular_selection(t, duration):
    # Two compact wood/drum impacts. Upper harmonics carry on iPad speakers;
    # the second settles a fifth lower, separate from the startup sonic mark.
    value = 0
    for start, frequency, gain in ((.015, 196, .65), (.30, 130.81, 1)):
        u = t - start
        if u < 0:
            continue
        envelope = (1 - math.exp(-u / .003)) * math.exp(-u / .14)
        phase = frequency * u + 22 * .018 * (1 - math.exp(-u / .018))
        value += gain * envelope * sum(a * math.sin(2 * math.pi * n * phase)
                                      for n, a in ((1, .48), (2, .32), (3, .12)))
    return value * min(1, max(0, (duration - t) / .12))


def kids_selection(t, duration):
    # Soft, ascending C/E/G marimba-like plucks with a tiny playful pitch lift.
    value = 0
    for start, frequency, gain in ((.02, 523.25, .70), (.23, 659.25, .82), (.44, 783.99, 1)):
        u = t - start
        if u < 0:
            continue
        envelope = (1 - math.exp(-u / .004)) * math.exp(-u / .135)
        phase = frequency * u - 14 * .024 * (1 - math.exp(-u / .024))
        value += gain * envelope * (math.sin(2 * math.pi * phase)
                                   + .13 * math.sin(2 * math.pi * phase * 3))
    return value * min(1, max(0, (duration - t) / .12))


if __name__ == "__main__":
    DEST.mkdir(parents=True, exist_ok=True)
    write("rewind-arrival.wav", 1.18, arrival)
    write("rewind-select.wav", .10, selection)
    write("rewind-select-regular.wav", .82, regular_selection)
    write("rewind-select-kids.wav", 1.02, kids_selection)
    print("Generated original mono PCM cues, including separate regular/Kids selection sounds.")
