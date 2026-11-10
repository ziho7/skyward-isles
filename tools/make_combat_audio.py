"""Warm short sword contacts and soft slime foley, deterministic 44.1 kHz PCM.

Run after make_audio.py. Original synthesis, no downloaded samples. Band-limited
noise supplies contact texture without old chirps / metallic ping or saturation.
"""
from pathlib import Path
import json
import math
import wave
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/audio'
SR = 44100
RNG = np.random.default_rng(4142026)
METRICS = {}


def noise(count, low=100, high=2400):
    """Smooth frequency shoulders avoid brittle hiss and spectral ringing."""
    source = RNG.normal(0, 1, count)
    frequencies = np.fft.rfftfreq(count, 1 / SR)
    response = (1 - np.exp(-(frequencies / low) ** 4)) * np.exp(-(frequencies / high) ** 4)
    filtered = np.fft.irfft(np.fft.rfft(source) * response, n=count)
    return filtered / max(.001, float(np.std(filtered)))


def envelope(t, attack=.002, decay=35):
    return (1 - np.exp(-t / attack)) * np.exp(-t * decay)


def write(name, signal, peak_db=-5.5):
    signal = signal - signal.mean()
    signal *= np.minimum(np.arange(len(signal)) / (SR * .0015), 1)
    signal *= np.minimum(np.arange(len(signal))[::-1] / (SR * .025), 1)
    signal *= 10 ** (peak_db / 20) / max(.001, float(np.max(np.abs(signal))))
    with wave.open(str(OUT / f'{name}.wav'), 'wb') as audio:
        audio.setnchannels(1)
        audio.setsampwidth(2)
        audio.setframerate(SR)
        audio.writeframes((signal * 32767).astype('<i2').tobytes())
    spectrum = np.abs(np.fft.rfft(signal)) ** 2
    high = np.fft.rfftfreq(len(signal), 1 / SR) > 5000
    METRICS[name] = {
        'duration': round(len(signal) / SR, 3),
        'peak_dbfs': round(float(20 * np.log10(np.max(np.abs(signal)))), 2),
        'energy_above_5khz_percent': round(float(spectrum[high].sum() / spectrum.sum() * 100), 5),
        'clipped_samples': int(np.sum(np.abs(signal) >= 1)),
    }
    print(name, METRICS[name])
    return signal


def impact(name, weight=1.0, variant=0):
    t = np.arange(int(SR * (.22 + weight * .04))) / SR
    contact = noise(len(t), 420, 2300 + variant * 100) * envelope(t, .0018, 95) * .14
    body = noise(len(t), 85, 650) * envelope(t, .003, 34 / weight) * .29
    gel = noise(len(t), 160, 1050) * envelope(t, .009, 48 / weight) * .10
    thump = np.sin(math.tau * (96 - variant * 4) * t) * envelope(t, .002, 42 / weight) * .12
    return write(name, contact + body + gel + thump, -5.0 if weight > 1 else -6.0)


def swing(name, skill=False):
    duration = .34 if skill else .20
    t = np.arange(int(SR * duration)) / SR
    shape = (t / duration) ** 1.1 * (1 - t / duration) ** 3.4
    return write(name, noise(len(t), 280, 2000 if skill else 1700) * shape, -9.0)


if __name__ == '__main__':
    OUT.mkdir(parents=True, exist_ok=True)
    (ROOT / 'captures').mkdir(exist_ok=True)
    samples = {'swing': swing('swing'), 'swing-skill': swing('swing-skill', True)}
    for index in range(1, 4):
        samples[f'hit-light-{index}'] = impact(f'hit-light-{index}', 1.0, index)
    samples['hit-heavy'] = impact('hit-heavy', 1.45)
    t = np.arange(int(SR * .38)) / SR
    skill = noise(len(t), 65, 900) * envelope(t, .004, 22) * .30
    skill += noise(len(t), 350, 2100) * envelope(t, .009, 30) * .15
    samples['hit-skill'] = write('hit-skill', skill, -4.5)
    t = np.arange(int(SR * .19)) / SR
    write('slime', noise(len(t), 100, 750) * envelope(t, .005, 33), -10)
    t = np.arange(int(SR * .24)) / SR
    write('hurt', noise(len(t), 65, 600) * envelope(t, .003, 28), -8)
    t = np.arange(int(SR * .25)) / SR
    write('dodge', noise(len(t), 180, 1400) * np.sin(np.pi * t / .25) ** 2, -12)
    # Preserve the noncombat portal chord in a full audio rebuild.
    t = np.arange(int(SR * 1.8)) / SR
    portal = noise(len(t), 100, 900) * np.sin(np.pi * t / 1.8) ** 2 * .025
    for delay, frequency in [(0, 261.63), (.13, 392), (.26, 523.25), (.39, 783.99)]:
        local = np.maximum(0, t - delay)
        portal += np.sin(math.tau * frequency * local) * (1 - np.exp(-local * 30)) * np.exp(-local * 3) * .11
    write('portal-open', portal)
    demo = np.zeros(SR * 5)
    for onset, hit in [(.15, 'hit-light-1'), (.83, 'hit-light-2'), (1.53, 'hit-heavy'), (3.08, 'hit-skill')]:
        for delay, key, db in [(0, 'swing-skill' if hit == 'hit-skill' else 'swing', -15), (.07, hit, -9)]:
            signal = samples[key] * 10 ** (db / 20)
            start = int((onset + delay) * SR)
            demo[start:start + len(signal)] += signal
    assert np.max(np.abs(demo)) < 1, 'Audition must not clip'
    with wave.open(str(ROOT / 'captures/combat-sound-preview.wav'), 'wb') as audio:
        audio.setnchannels(1)
        audio.setsampwidth(2)
        audio.setframerate(SR)
        audio.writeframes((demo * 32767).astype('<i2').tobytes())
    (ROOT / 'captures/combat-audio-metrics.json').write_text(json.dumps(METRICS, indent=2) + '\n')
