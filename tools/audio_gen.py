#!/usr/bin/env python3
"""AI 娘守店记 —— 离线音频生成器（纯 Python，无第三方依赖）。

把背景音乐和全部音效渲染成音频文件，游戏里直接加载，不必在手机上实时合成。

    python3 tools/audio_gen.py           # 全部生成到 art/audio/
    python3 tools/audio_gen.py music     # 只生成音乐（需要 ffmpeg + libvorbis 转 .ogg）
    python3 tools/audio_gen.py sfx       # 只生成音效（16-bit .wav）

音乐都是整小节长度，渲染时把尾音和混响折回开头，所以循环播放没有接缝。
"""
import array
import math
import os
import random
import subprocess
import sys
import tempfile
import wave

SR = 44100
TAU = 2.0 * math.pi
sin = math.sin
exp = math.exp
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "art", "audio")
rng = random.Random(20261107)

# ---------------------------------------------------------------- helpers

NOTE = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def m(name):
	"""'F#4' -> MIDI number."""
	i, acc = 1, 0
	while name[i] in "#b":
		acc += 1 if name[i] == "#" else -1
		i += 1
	return 12 * (int(name[i:]) + 1) + NOTE[name[0]] + acc


def hz(note):
	n = m(note) if isinstance(note, str) else note
	return 440.0 * 2.0 ** ((n - 69) / 12.0)


def decay_k(seconds):
	return exp(-1.0 / (seconds * SR))


def blep(t, dt):
	if t < dt:
		t /= dt
		return t + t - t * t - 1.0
	if t > 1.0 - dt:
		t = (t - 1.0) / dt
		return t * t + t + t + 1.0
	return 0.0


def noise():
	return rng.random() * 2.0 - 1.0


def lowpass(x, cutoff):
	a = 1.0 - exp(-TAU * cutoff / SR)
	y, s = [0.0] * len(x), 0.0
	for i, v in enumerate(x):
		s += a * (v - s)
		y[i] = s
	return y


def highpass(x, cutoff):
	a = 1.0 - exp(-TAU * cutoff / SR)
	y, s = [0.0] * len(x), 0.0
	for i, v in enumerate(x):
		s += a * (v - s)
		y[i] = v - s
	return y


def mixin(dst, src, start=0, gain=1.0):
	"""Add src into dst at sample offset (grows dst if needed)."""
	end = start + len(src)
	if end > len(dst):
		dst.extend([0.0] * (end - len(dst)))
	dst[start:end] = [a + b * gain for a, b in zip(dst[start:end], src)]
	return dst


def at(seconds):
	return int(round(seconds * SR))


def fade_tail(x, seconds=0.01):
	n = min(len(x), at(seconds))
	for i in range(n):
		x[len(x) - 1 - i] *= i / n
	return x


def normalize(x, peak=0.9):
	top = max(1e-9, max(abs(v) for v in x))
	g = peak / top
	y = [v * g for v in x]
	end = len(y)
	while end > 1 and abs(y[end - 1]) < 0.0015:  # drop the inaudible tail (below -56 dB)
		end -= 1
	return fade_tail(y[:min(len(y), end + at(0.01))], 0.01)


def write_wav(path, left, right=None):
	data = array.array("h")
	if right is None:
		data.extend(int(max(-1.0, min(1.0, v)) * 32767) for v in left)
		channels = 1
	else:
		inter = [0.0] * (2 * len(left))
		inter[0::2] = left
		inter[1::2] = right
		data.extend(int(max(-1.0, min(1.0, v)) * 32767) for v in inter)
		channels = 2
	with wave.open(path, "wb") as w:
		w.setnchannels(channels)
		w.setsampwidth(2)
		w.setframerate(SR)
		w.writeframes(data.tobytes())

# ---------------------------------------------------------------- instruments (mono note renderers)


def ep(freq, dur, vel=0.7, release=0.2):
	"""FM electric piano (Rhodes-ish): warm body + short tine bark."""
	n = at(dur + release)
	off = at(dur)
	out = [0.0] * n
	w = TAU * freq / SR
	kI, kA, kB, kR = decay_k(0.3), decay_k(1.7), decay_k(0.01), decay_k(release * 0.35)
	idx, amp, bark = 0.7 + 1.5 * vel, vel, 0.22 * vel
	att = at(0.003)
	for i in range(n):
		ph = w * i
		v = amp * sin(ph + (idx + 0.25) * sin(ph)) + bark * sin(14.0 * ph)
		if i < att:
			v *= i / att
		out[i] = v
		idx *= kI
		amp *= kA
		bark *= kB
		if i >= off:
			amp *= kR
	return out


def bell(freq, vel=0.7, length=1.2, partials=((1.0, 1.0, 1.0), (2.0, 0.16, 0.35), (4.07, 0.07, 0.14))):
	"""Music box / celesta: mostly sine with a little inharmonic shimmer."""
	n = at(length * 3.0)
	out = [0.0] * n
	for ratio, gain, life in partials:
		f = freq * ratio
		if f > SR * 0.45:
			continue
		w = TAU * f / SR
		a = gain * vel
		k = decay_k(length * life)
		att = at(0.0015)
		for i in range(n):
			v = a * sin(w * i)
			if i < att:
				v *= i / att
			out[i] += v
			a *= k
	return fade_tail(out, 0.05)


def pluck(freq, dur, vel=0.6, bright=0.5, decay=0.996):
	"""Karplus-Strong string (nylon guitar / harp) with all-pass fine tuning."""
	period = SR / freq
	N = int(period - 0.5)
	frac = period - 0.5 - N
	if frac < 0.1:
		N -= 1
		frac += 1.0
	C = (1.0 - frac) / (1.0 + frac)
	buf = [noise() for _ in range(N)]
	for _ in range(int(1 + (1.0 - bright) * 4)):  # softer pluck = smoother initial noise
		buf = [0.5 * (buf[i] + buf[i - 1]) for i in range(N)]
	mean = sum(buf) / N
	buf = [(b - mean) * vel for b in buf]
	n = at(dur + 0.08)
	off = at(dur)
	kR = decay_k(0.03)
	out = [0.0] * n
	idx, xp, yp, rel = 0, 0.0, 0.0, 1.0
	for i in range(n):
		a = buf[idx]
		nxt = idx + 1 if idx + 1 < N else 0
		x = decay * 0.5 * (a + buf[nxt])
		y = C * x + xp - C * yp
		xp, yp = x, y
		buf[idx] = y
		if i >= off:
			rel *= kR
		out[i] = a * rel
		idx = nxt
	return out


def upright(freq, dur, vel=0.8):
	"""Warm upright / finger bass."""
	n = at(dur + 0.08)
	off = at(dur)
	out = [0.0] * n
	w = TAU * freq / SR
	kA, k2, k3, kR = decay_k(0.9), decay_k(0.22), decay_k(0.09), decay_k(0.025)
	a, a2, a3 = vel, 0.5 * vel, 0.25 * vel
	att = at(0.006)
	for i in range(n):
		ph = w * i
		v = a * sin(ph) + a2 * sin(2 * ph) + a3 * sin(3 * ph)
		if i < att:
			v *= i / att
		out[i] = v
		a *= kA
		a2 *= k2
		a3 *= k3
		if i >= off:
			a *= kR
			a2 *= kR
			a3 *= kR
	return out


def synbass(freq, dur, vel=0.8, cut0=2600.0, cut1=320.0, fdec=0.08, sub=0.55):
	"""Plucky saw bass with a filter envelope and a sine sub."""
	n = at(dur + 0.04)
	off = at(dur)
	out = [0.0] * n
	dt = freq / SR
	ph = 0.0
	l1 = l2 = 0.0
	env_c = 1.0
	kc, kA, kR = decay_k(fdec), decay_k(0.6), decay_k(0.012)
	amp = vel
	att = at(0.003)
	for i in range(n):
		saw = 2.0 * ph - 1.0 - blep(ph, dt)
		cutoff = cut1 + (cut0 - cut1) * env_c
		a = min(1.0, TAU * cutoff / SR)
		l1 += a * (saw - l1)
		l2 += a * (l1 - l2)
		v = (l2 * 0.75 + sub * sin(TAU * ph)) * amp
		if i < att:
			v *= i / att
		out[i] = v
		ph += dt
		if ph >= 1.0:
			ph -= 1.0
		env_c *= kc
		amp *= kA
		if i >= off:
			amp *= kR
	return out


def lead(freq, dur, vel=0.7, duty=0.38, cut=4200.0, vib=0.005, saw=False):
	"""Soft square (or saw) lead with delayed vibrato."""
	n = at(dur + 0.07)
	off = at(dur)
	out = [0.0] * n
	ph = 0.0
	a = min(1.0, TAU * cut / SR)
	s1 = s2 = 0.0
	amp = 0.0
	att = at(0.006)
	kS, kR = decay_k(0.25), decay_k(0.02)
	sustain = 0.72 * vel
	peak = vel
	vstart = at(0.14)
	for i in range(n):
		f = freq
		if i > vstart:
			f *= 1.0 + vib * sin(TAU * 5.6 * (i - vstart) / SR) * min(1.0, (i - vstart) / at(0.2))
		dt = f / SR
		if saw:
			v = 2.0 * ph - 1.0 - blep(ph, dt)
		else:
			v = 1.0 if ph < duty else -1.0
			v += blep(ph, dt)
			t2 = ph - duty
			if t2 < 0.0:
				t2 += 1.0
			v -= blep(t2, dt)
		s1 += a * (v - s1)
		s2 += a * (s1 - s2)
		if i < att:
			amp = peak * i / att
		elif i < off:
			amp = sustain + (amp - sustain) * kS
		else:
			amp *= kR
		out[i] = s2 * amp
		ph += dt
		if ph >= 1.0:
			ph -= 1.0
	return out


def pad(freq, dur, vel=0.5, cut=1800.0, attack=0.35, release=0.5, detune=0.006):
	"""Three detuned saws through a soft low-pass."""
	n = at(dur + release)
	off = at(dur)
	out = [0.0] * n
	phs = [rng.random() for _ in range(3)]
	dts = [freq * (1.0 + d) / SR for d in (-detune, 0.0, detune)]
	a = min(1.0, TAU * cut / SR)
	s1 = s2 = 0.0
	kR = decay_k(release * 0.4)
	att = at(attack)
	amp = 0.0
	for i in range(n):
		v = 0.0
		for j in range(3):
			p, dt = phs[j], dts[j]
			v += 2.0 * p - 1.0 - blep(p, dt)
			p += dt
			phs[j] = p - 1.0 if p >= 1.0 else p
		s1 += a * (v - s1)
		s2 += a * (s1 - s2)
		if i < att:
			amp = vel * i / att
		elif i >= off:
			amp *= kR
		out[i] = s2 * amp * 0.33
	return out

# ---------------------------------------------------------------- drums


def kick(vel=1.0, punch=110.0, base=46.0, length=0.28):
	n = at(length * 2.2)
	out = [0.0] * n
	ph = 0.0
	kf, ka = decay_k(0.035), decay_k(length)
	fenv, amp = 1.0, vel
	for i in range(n):
		ph += TAU * (base + punch * fenv) / SR
		click = noise() * 0.25 * exp(-i / (0.0025 * SR)) if i < 400 else 0.0
		out[i] = (sin(ph) + click) * amp
		fenv *= kf
		amp *= ka
	return fade_tail(out)


def snare(vel=0.8, tone=190.0, snap=0.14):
	n = at(0.35)
	body = [0.0] * n
	kT, kN = decay_k(0.05), decay_k(snap)
	t_amp, n_amp = 0.55 * vel, 0.8 * vel
	nz = [noise() for _ in range(n)]
	nz = highpass(lowpass(nz, 7000), 900)
	for i in range(n):
		body[i] = t_amp * sin(TAU * tone * i / SR) + n_amp * nz[i]
		t_amp *= kT
		n_amp *= kN
	return fade_tail(body)


def clap(vel=0.8):
	n = at(0.3)
	nz = highpass(lowpass([noise() for _ in range(n)], 5200), 1100)
	out = [0.0] * n
	for i in range(n):
		t = i / SR
		e = 0.0
		for start in (0.0, 0.010, 0.021):
			if t >= start:
				e += exp(-(t - start) / 0.006)
		e = 0.55 * e + exp(-t / 0.11) * (1.0 if t > 0.021 else 0.0)
		out[i] = nz[i] * e * vel
	return fade_tail(out)


def hat(vel=0.5, length=0.035):
	n = at(max(0.06, length * 4))
	nz = highpass([noise() for _ in range(n)], 7000)
	k = decay_k(length)
	a = vel
	for i in range(n):
		nz[i] *= a
		a *= k
	return fade_tail(nz)


def shaker(vel=0.4):
	n = at(0.09)
	nz = highpass(lowpass([noise() for _ in range(n)], 9000), 4500)
	for i in range(n):
		t = i / SR
		nz[i] *= vel * min(1.0, t / 0.018) * exp(-max(0.0, t - 0.018) / 0.03)
	return fade_tail(nz)


def rim(vel=0.5, freq=1700.0):
	n = at(0.08)
	out = [0.0] * n
	a = vel
	k = decay_k(0.018)
	for i in range(n):
		out[i] = a * (sin(TAU * freq * i / SR) + 0.4 * sin(TAU * freq * 2.31 * i / SR))
		a *= k
	return out


def tom(vel=0.8, f0=150.0, f1=85.0):
	n = at(0.45)
	out = [0.0] * n
	ph = 0.0
	a = vel
	k = decay_k(0.2)
	for i in range(n):
		f = f1 + (f0 - f1) * exp(-i / (0.06 * SR))
		ph += TAU * f / SR
		out[i] = a * sin(ph)
		a *= k
	return fade_tail(out)


def crash(vel=0.5, length=1.4):
	n = at(length * 1.6)
	nz = highpass([noise() for _ in range(n)], 5000)
	k = decay_k(length * 0.45)
	a = vel
	for i in range(n):
		nz[i] *= a
		a *= k
	return fade_tail(nz, 0.05)

# ---------------------------------------------------------------- effects


def comb(x, delay, feedback, damp):
	y = [0.0] * len(x)
	buf = [0.0] * delay
	idx, store, d1 = 0, 0.0, 1.0 - damp
	for i, v in enumerate(x):
		o = buf[idx]
		store = o * d1 + store * damp
		buf[idx] = v + store * feedback
		y[i] = o
		idx += 1
		if idx == delay:
			idx = 0
	return y


def allpass(x, delay, g=0.5):
	y = [0.0] * len(x)
	buf = [0.0] * delay
	idx = 0
	for i, v in enumerate(x):
		o = buf[idx]
		y[i] = o - v
		buf[idx] = v + o * g
		idx += 1
		if idx == delay:
			idx = 0
	return y


def reverb(x, room=0.84, damp=0.25, spread=23):
	"""Small Freeverb: mono in, stereo out."""
	inp = [v * 0.02 for v in x]
	outs = []
	for offset in (0, spread):
		acc = [0.0] * len(x)
		for d in (1116, 1188, 1277, 1356, 1422):
			c = comb(inp, d + offset, room, damp)
			acc = [a + b for a, b in zip(acc, c)]
		for d in (556, 441, 341):
			acc = allpass(acc, d + offset)
		outs.append(acc)
	return outs


def pingpong(x, delay_s, feedback=0.38, damp_hz=3500.0):
	"""Stereo ping-pong echo (wet only): first repeat left, then right, then left..."""
	d = at(delay_s)
	n = len(x)
	left, right = [0.0] * n, [0.0] * n
	a = 1.0 - exp(-TAU * damp_hz / SR)
	sl = sr = 0.0
	for i in range(d, n):
		sl += a * (x[i - d] + right[i - d] * feedback - sl)
		sr += a * (left[i - d] * feedback - sr)
		left[i] = sl
		right[i] = sr
	return left, right

# ---------------------------------------------------------------- music mixer


class Song:
	def __init__(self, bpm, bars, beats=4):
		self.spb = 60.0 / bpm
		self.n = at(bars * beats * self.spb)
		self.buses = {}

	def bus(self, name, pan=0.0, gain=1.0, rev=0.2, echo=0.0, pump=0.0, drive=0.0):
		self.buses[name] = {"buf": [0.0] * self.n, "pan": pan, "gain": gain, "rev": rev, "echo": echo, "pump": pump, "drive": drive}

	def t(self, bar, beat):
		return (bar * 4 + beat) * self.spb

	def add(self, name, seconds, samples, gain=1.0, human=0.004):
		buf = self.buses[name]["buf"]
		n = self.n
		start = (at(seconds + rng.uniform(-human, human)) if human else at(seconds)) % n
		pos = 0
		while pos < len(samples):
			chunk = min(len(samples) - pos, n - start)
			buf[start:start + chunk] = [a + b * gain for a, b in zip(buf[start:start + chunk], samples[pos:pos + chunk])]
			pos += chunk
			start = 0

	def render(self, echo_beats=0.75, room=0.84):
		n = self.n
		L, R = [0.0] * n, [0.0] * n
		rev_in, echo_in = [0.0] * n, [0.0] * n
		beat = self.spb * SR
		for b in self.buses.values():
			if b["drive"]:
				d = b["drive"]
				b["buf"] = [math.tanh(v * d) / math.tanh(d) for v in b["buf"]]
			if b["pump"]:
				depth = b["pump"]
				b["buf"] = [v * (1.0 - depth * max(0.0, 1.0 - ((i % beat) / beat) / 0.45) ** 2) for i, v in enumerate(b["buf"])]
			p = (b["pan"] + 1.0) * math.pi / 4.0
			gl, gr = math.cos(p) * b["gain"], math.sin(p) * b["gain"]
			buf = b["buf"]
			L = [a + v * gl for a, v in zip(L, buf)]
			R = [a + v * gr for a, v in zip(R, buf)]
			if b["rev"]:
				g = b["rev"] * b["gain"]
				rev_in = [a + v * g for a, v in zip(rev_in, buf)]
			if b["echo"]:
				g = b["echo"] * b["gain"]
				echo_in = [a + v * g for a, v in zip(echo_in, buf)]
		# Effects run over two copies so their tails wrap into the loop start.
		if any(echo_in):
			el, er = pingpong(echo_in + echo_in, echo_beats * self.spb)
			L = [a + v for a, v in zip(L, el[n:])]
			R = [a + v for a, v in zip(R, er[n:])]
			rev_in = [a + v * 0.5 for a, v in zip(rev_in, echo_in)]
		if any(rev_in):
			rl, rr = reverb(rev_in + rev_in, room)
			L = [a + v for a, v in zip(L, rl[n:])]
			R = [a + v for a, v in zip(R, rr[n:])]
		return master(L, R)


def master(L, R, target_rms=0.16):
	# Gentle low cut (run over two copies so the loop stays seamless), level to a target loudness, soft-limit peaks.
	n = len(L)
	L, R = highpass(L + L, 28.0)[n:], highpass(R + R, 28.0)[n:]
	rms = math.sqrt((sum(v * v for v in L) + sum(v * v for v in R)) / (2 * len(L)))
	g = target_rms / max(rms, 1e-9)

	def limit(v):
		v *= g
		a = abs(v)
		if a <= 0.72:
			return v
		s = 0.72 + 0.26 * math.tanh((a - 0.72) / 0.26)
		return s if v > 0 else -s
	return [limit(v) for v in L], [limit(v) for v in R]


def chord_notes(names):
	return [hz(x) for x in names]

# ---------------------------------------------------------------- music: menu (bossa café)


def song_menu():
	s = Song(100, 16)
	s.bus("guitar", pan=-0.3, gain=0.55, rev=0.25)
	s.bus("bass", pan=0.0, gain=0.8, rev=0.06)
	s.bus("ep", pan=0.25, gain=0.36, rev=0.35)
	s.bus("melody", pan=0.12, gain=0.5, rev=0.38)
	s.bus("box", pan=0.3, gain=0.32, rev=0.45)
	s.bus("perc", pan=0.2, gain=0.42, rev=0.12)
	s.bus("kick", pan=0.0, gain=0.5, rev=0.0)
	F7 = ["E3", "A3", "C4", "G4"]
	bars = [
		[(0, 4, "F2", F7)], [(0, 4, "F2", ["D3", "A3", "C4", "G4"])],
		[(0, 4, "G2", ["F3", "Bb3", "D4", "A4"])], [(0, 4, "C3", ["E3", "Bb3", "D4", "G4"])],
		[(0, 4, "A2", ["G3", "C4", "E4"])], [(0, 4, "D3", ["F#3", "C4", "E4", "A4"])],
		[(0, 4, "G2", ["F3", "Bb3", "D4", "A4"])], [(0, 4, "C3", ["E3", "Bb3", "D4", "G4"])],
		[(0, 4, "F2", F7)], [(0, 4, "F2", ["Eb3", "A3", "C4", "G4"])],
		[(0, 4, "Bb2", ["A3", "D4", "F4", "C5"])], [(0, 4, "Bb2", ["G3", "Db4", "F4", "C5"])],
		[(0, 4, "A2", ["G3", "C4", "E4"])], [(0, 4, "D3", ["F#3", "C4", "Eb4", "A4"])],
		[(0, 2, "G2", ["F3", "Bb3", "D4"]), (2, 2, "C3", ["E3", "Bb3", "D4"])],
		[(0, 2, "F2", ["E3", "A3", "C4"]), (2, 2, "C3", ["E3", "Bb3", "D4"])],
	]
	melody = [
		[(1, .5, "A4"), (1.5, .5, "C5"), (2, 1.5, "E5"), (3.5, .5, "D5")],
		[(0, 2, "C5"), (2, 1, "A4"), (3, 1, "G4")],
		[(0, 1.5, "Bb4"), (1.5, .5, "A4"), (2, 1, "G4"), (3, 1, "F4")],
		[(0, 1.5, "E4"), (1.5, .5, "G4"), (2, 1.5, "Bb4"), (3.5, .5, "A4")],
		[(0, 1.5, "C5"), (1.5, .5, "E5"), (2, 1, "D5"), (3, 1, "C5")],
		[(0, 1.5, "D5"), (1.5, .5, "C5"), (2, 1, "A4"), (3, 1, "F#4")],
		[(0, 1.5, "G4"), (1.5, .5, "Bb4"), (2, 1.5, "D5"), (3.5, .5, "C5")],
		[(0, 1, "Bb4"), (1, 1, "A4"), (2, 2, "G4")],
		[(.5, .5, "A4"), (1, .5, "C5"), (1.5, 1.5, "F5"), (3, 1, "E5")],
		[(0, 1.5, "Eb5"), (1.5, .5, "D5"), (2, 1, "C5"), (3, 1, "A4")],
		[(0, 1.5, "D5"), (1.5, .5, "F5"), (2, 1.5, "A5"), (3.5, .5, "G5")],
		[(0, 1.5, "F5"), (1.5, .5, "Db5"), (2, 2, "Bb4")],
		[(0, 1, "C5"), (1, .5, "E5"), (1.5, 1.5, "G5"), (3, 1, "E5")],
		[(0, 1, "F#5"), (1, 1, "Eb5"), (2, 1, "C5"), (3, 1, "A4")],
		[(0, 1, "Bb4"), (1, 1, "D5"), (2, 1, "E5"), (3, 1, "G5")],
		[(0, 2, "F5"), (3, .5, "C5"), (3.5, .5, "D5")],
	]
	comp = [[0, 1.5, 3], [0.5, 2, 3.5]]
	for bar, parts in enumerate(bars):
		for start, length, root, voicing in parts:
			r = hz(root)
			fifth = r * 1.5 if root[0] not in "B" else r * 1.5
			# bossa bass: root (dotted quarter) / fifth / fifth / root pickup
			if length == 4:
				pattern = [(0, 1.5, r), (1.5, .5, fifth), (2, 1.5, fifth), (3.5, .5, r)]
			else:
				pattern = [(start, 1.5, r), (start + 1.5, .5, fifth)]
			for b, d, f in pattern:
				s.add("bass", s.t(bar, b), upright(f, d * s.spb * 0.92, 0.7 if b in (0, 2) else 0.5))
			# nylon guitar comping, strummed upward
			hits = [h for h in comp[bar % 2] if start <= h < start + length]
			for k, h in enumerate(hits):
				nxt = hits[k + 1] if k + 1 < len(hits) else start + length
				dur = min(1.2, (nxt - h) * s.spb * 0.95)
				for v, note in enumerate(voicing):
					s.add("guitar", s.t(bar, h) + v * 0.011, pluck(hz(note), dur, 0.55 + rng.uniform(-.06, .06), bright=0.35, decay=0.9975))
			# soft EP pads in the second half
			if bar >= 8:
				for note in voicing[:3]:
					s.add("ep", s.t(bar, start), ep(hz(note), length * s.spb * 0.98, 0.32))
	for bar, notes in enumerate(melody):
		for b, d, note in notes:
			f = hz(note)
			if bar < 8:
				s.add("box", s.t(bar, b), bell(f * 2.0, 0.55, length=0.9))
				s.add("melody", s.t(bar, b), bell(f, 0.8, length=1.1))
			else:
				s.add("melody", s.t(bar, b), ep(f, d * s.spb * 0.95, 0.62))
				s.add("box", s.t(bar, b), bell(f * 2.0, 0.45, length=0.8))
	for bar in range(16):
		for e in range(8):
			s.add("perc", s.t(bar, e * 0.5), shaker(0.34 if e % 2 else 0.2))
		clave = [0, 1.5, 3] if bar % 2 == 0 else [1, 2]
		for b in clave:
			s.add("perc", s.t(bar, b), rim(0.32))
		for b, v in ((0, 0.8), (1.5, 0.35), (2, 0.65), (3.5, 0.3)):
			s.add("kick", s.t(bar, b), kick(v, punch=70.0, base=48.0, length=0.2))
	return s.render(room=0.82)

# ---------------------------------------------------------------- music: battle (bright J-pop)


def song_battle():
	s = Song(128, 16)
	s.bus("kick", gain=0.9, rev=0.0)
	s.bus("snare", pan=0.05, gain=0.5, rev=0.18)
	s.bus("hat", pan=0.3, gain=0.26, rev=0.05)
	s.bus("bass", gain=0.62, rev=0.0)
	s.bus("stab", pan=-0.3, gain=0.34, rev=0.22)
	s.bus("pad", pan=0.0, gain=0.22, rev=0.4)
	s.bus("arp", pan=0.4, gain=0.2, rev=0.3, echo=0.35)
	s.bus("lead", pan=-0.05, gain=0.32, rev=0.25, echo=0.3)
	s.bus("crash", pan=-0.2, gain=0.25, rev=0.2)
	G = ["G3", "B3", "D4", "F#4"]
	A7 = ["G3", "A3", "C#4", "E4"]
	Fm = ["F#3", "A3", "C#4", "E4"]
	Bm = ["F#3", "A3", "B3", "D4"]
	chords = [("G2", G), ("A2", A7), ("F#2", Fm), ("B2", Bm), ("G2", G), ("A2", A7), ("F#2", ["E3", "A#3", "C#4", "F#4"]), ("B2", Bm),
		("E2", ["G3", "B3", "D4", "E4"]), ("A2", A7), ("D2", ["F#3", "A3", "C#4", "E4"]), ("B2", Bm),
		("G2", G), ("A2", A7), ("B2", Bm), ("A2", ["D4", "E4", "A3", "G3"])]
	melody = [
		[(0, .5, "D5"), (.5, .5, "F#5"), (1, .5, "A5"), (1.5, .5, "F#5"), (2, 1, "G5"), (3, .5, "F#5"), (3.5, .5, "E5")],
		[(0, 1, "E5"), (1, .5, "C#5"), (1.5, .5, "E5"), (2, 1, "A5"), (3, .5, "G5"), (3.5, .5, "E5")],
		[(0, 1.5, "F#5"), (1.5, .5, "E5"), (2, 1, "C#5"), (3, 1, "A4")],
		[(0, .5, "B4"), (.5, .5, "D5"), (1, 1, "F#5"), (2, .5, "E5"), (2.5, .5, "D5"), (3, .5, "C#5"), (3.5, .5, "D5")],
		[(0, 1, "B5"), (1, .5, "A5"), (1.5, .5, "G5"), (2, 1, "F#5"), (3, 1, "D5")],
		[(0, .5, "E5"), (.5, .5, "F#5"), (1, 1, "G5"), (2, 1.5, "A5")],
		[(0, .5, "C#5"), (.5, .5, "E5"), (1, .5, "F#5"), (1.5, 2, "A#5")],
		[(0, 2, "B5"), (2, .5, "A5"), (2.5, .5, "F#5"), (3, 1, "D5")],
		[(0, .5, "G5"), (.5, .5, "F#5"), (1, .5, "E5"), (1.5, .5, "D5"), (2, 1, "E5"), (3, 1, "B4")],
		[(0, .5, "C#5"), (.5, .5, "E5"), (1, 1, "A5"), (2, 1, "G5"), (3, 1, "E5")],
		[(0, 1.5, "F#5"), (1.5, .5, "E5"), (2, .5, "D5"), (2.5, .5, "E5"), (3, .5, "F#5"), (3.5, .5, "A5")],
		[(0, 1.5, "B5"), (1.5, .5, "A5"), (2, 2, "F#5")],
		[(0, 1, "D6"), (1, .5, "B5"), (1.5, .5, "A5"), (2, 1, "G5"), (3, 1, "F#5")],
		[(0, .5, "E5"), (.5, .5, "G5"), (1, 1, "A5"), (2, 1, "C#6"), (3, 1, "A5")],
		[(0, 1, "D6"), (1, 1, "C#6"), (2, 1, "B5"), (3, 1, "A5")],
		[(0, .5, "G5"), (.5, .5, "F#5"), (1, 2, "E5"), (3, .5, "D5"), (3.5, .5, "E5")],
	]
	for bar, (root, voicing) in enumerate(chords):
		r = hz(root)
		for e in range(8):
			f = r * (2.0 if e in (2, 6) else 1.0)
			if e == 7:
				f = r * 1.5
			s.add("bass", s.t(bar, e * 0.5), synbass(f, 0.42 * s.spb, 0.85 if e % 2 == 0 else 0.65), human=0.0)
		for e in (0.5, 1.5, 2.5, 3.5):
			for note in voicing:
				s.add("stab", s.t(bar, e), ep(hz(note), 0.22 * s.spb, 0.5, release=0.08), human=0.0)
		for note in voicing[:3]:
			s.add("pad", s.t(bar, 0), pad(hz(note), 4 * s.spb, 0.5, cut=1500.0, attack=0.25, release=0.3))
		if bar >= 8:
			tones = [hz(x) * 2.0 for x in voicing]
			for k in range(16):
				f = tones[(k if (k // 4) % 2 == 0 else 3 - k % 4) % len(tones)]
				s.add("arp", s.t(bar, k * 0.25), bell(f, 0.5, length=0.35), human=0.0)
	for bar, notes in enumerate(melody):
		for b, d, note in notes:
			s.add("lead", s.t(bar, b), lead(hz(note), d * s.spb * 0.9, 0.7), human=0.0)
	for bar in range(16):
		for b in (0, 2, 2.5):
			s.add("kick", s.t(bar, b), kick(1.0 if b != 2.5 else 0.7), human=0.0)
		for b in (1, 3):
			s.add("snare", s.t(bar, b), clap(0.85), human=0.0)
			s.add("snare", s.t(bar, b), snare(0.5), human=0.0)
		for k in range(16):
			b = k * 0.25
			if k == 14:
				s.add("hat", s.t(bar, b), hat(0.55, 0.18))
			elif k % 2 == 0:
				s.add("hat", s.t(bar, b), hat(0.55 if k % 4 == 2 else 0.4))
			else:
				s.add("hat", s.t(bar, b), hat(0.18))
		if bar in (7, 15):
			for k in range(8):
				s.add("snare", s.t(bar, 2 + k * 0.25), snare(0.25 + 0.07 * k), human=0.0)
		if bar in (0, 8):
			s.add("crash", s.t(bar, 0), crash(0.7))
	return s.render(echo_beats=0.75, room=0.8)

# ---------------------------------------------------------------- music: boss (driving minor)


def song_boss():
	s = Song(144, 16)
	s.bus("kick", gain=0.95, rev=0.0)
	s.bus("snare", pan=0.05, gain=0.55, rev=0.2)
	s.bus("hat", pan=0.35, gain=0.22, rev=0.05)
	s.bus("tom", pan=-0.15, gain=0.6, rev=0.2)
	s.bus("bass", gain=0.6, rev=0.0)
	s.bus("pad", gain=0.3, rev=0.45)
	s.bus("arp", pan=-0.4, gain=0.17, rev=0.25, echo=0.3)
	s.bus("lead", pan=0.1, gain=0.3, rev=0.3, echo=0.25)
	s.bus("hit", gain=0.42, rev=0.5)
	s.bus("crash", pan=0.2, gain=0.28, rev=0.25)
	Dm = ("D2", ["D3", "F3", "A3"])
	Bb = ("Bb1", ["D3", "F3", "Bb3"])
	C = ("C2", ["E3", "G3", "C4"])
	Gm = ("G1", ["D3", "G3", "Bb3"])
	A = ("A1", ["C#3", "E3", "A3"])
	A7 = ("A1", ["C#3", "E3", "G3"])
	chords = [Dm, Dm, Bb, C, Dm, Dm, Gm, A, Bb, C, Dm, Dm, Bb, C, A, A7]
	melody = [
		[(0, 1.5, "D5"), (1.5, .5, "A4"), (2, .5, "D5"), (2.5, .5, "E5"), (3, 1, "F5")],
		[(0, 1, "E5"), (1, 1, "D5"), (2, 1, "C5"), (3, 1, "A4")],
		[(0, 1.5, "Bb4"), (1.5, .5, "C5"), (2, 1, "D5"), (3, 1, "F5")],
		[(0, 1.5, "E5"), (1.5, .5, "D5"), (2, 1, "C5"), (3, 1, "G4")],
		[(0, 1.5, "A5"), (1.5, .5, "F5"), (2, .5, "D5"), (2.5, .5, "E5"), (3, 1, "F5")],
		[(0, 1, "G5"), (1, 1, "F5"), (2, 1, "E5"), (3, 1, "D5")],
		[(0, 1, "D5"), (1, 1, "G5"), (2, 1, "Bb5"), (3, 1, "A5")],
		[(0, 2, "A5"), (2, .5, "G5"), (2.5, .5, "F5"), (3, 1, "E5")],
		[(0, 1.5, "F5"), (1.5, .5, "D5"), (2, 1, "Bb4"), (3, 1, "D5")],
		[(0, 1.5, "E5"), (1.5, .5, "C5"), (2, 1, "G5"), (3, 1, "E5")],
		[(0, 1, "F5"), (1, 1, "A5"), (2, 2, "D6")],
		[(0, 1, "C6"), (1, 1, "A5"), (2, 1, "F5"), (3, 1, "D5")],
		[(0, 1.5, "D6"), (1.5, .5, "C6"), (2, 1, "Bb5"), (3, 1, "F5")],
		[(0, 1.5, "G5"), (1.5, .5, "E5"), (2, 1, "C6"), (3, 1, "G5")],
		[(0, 1, "A5"), (1, 1, "C#6"), (2, 2, "E6")],
		[(0, 1, "G5"), (1, 1, "F5"), (2, 1, "E5"), (3, 1, "C#5")],
	]
	for bar, (root, voicing) in enumerate(chords):
		r = hz(root)
		for e in range(8):
			f = r * (2.0 if e in (2, 5, 7) else 1.0)
			s.add("bass", s.t(bar, e * 0.5), synbass(f, 0.45 * s.spb, 0.9 if e % 2 == 0 else 0.7, cut0=1800.0, cut1=260.0, fdec=0.06), human=0.0)
		for note in voicing:
			s.add("pad", s.t(bar, 0), pad(hz(note), 4 * s.spb, 0.55, cut=1300.0, attack=0.12, release=0.25))
		tones = [hz(x) * 2.0 for x in voicing] + [hz(voicing[0]) * 4.0]
		order = [0, 1, 2, 3, 2, 1, 0, 1, 2, 3, 2, 1, 0, 2, 3, 2]
		for k in range(16):
			s.add("arp", s.t(bar, k * 0.25), lead(tones[order[k]], 0.2 * s.spb, 0.55, duty=0.25, cut=3000.0, vib=0.0), human=0.0)
	for bar, notes in enumerate(melody):
		for b, d, note in notes:
			s.add("lead", s.t(bar, b), lead(hz(note), d * s.spb * 0.92, 0.75, cut=3200.0, saw=True), human=0.0)
	for bar in range(16):
		for b in (0, 1, 2, 3):
			s.add("kick", s.t(bar, b), kick(1.0, punch=130.0, base=50.0, length=0.22), human=0.0)
		s.add("kick", s.t(bar, 3.75), kick(0.6, punch=130.0, base=50.0, length=0.18), human=0.0)
		for b in (1, 3):
			s.add("snare", s.t(bar, b), snare(0.9, tone=210.0, snap=0.16), human=0.0)
		for k in range(16):
			s.add("hat", s.t(bar, k * 0.25), hat(0.5 if k % 2 == 0 else 0.25, 0.03), human=0.0)
		if bar in (0, 8):
			s.add("crash", s.t(bar, 0), crash(0.8, 1.8))
			hit = [0.0] * at(0.9)
			for note in ("D3", "A3", "D4", "F4", "A4"):
				mixin(hit, pad(hz(note), 0.18, 0.9, cut=4000.0, attack=0.004, release=0.5))
			s.add("hit", s.t(bar, 0), hit, human=0.0)
		if bar == 15:
			for k, f in enumerate((180.0, 160.0, 140.0, 120.0, 110.0, 100.0, 90.0, 80.0)):
				s.add("tom", s.t(bar, 2 + k * 0.25), tom(0.8, f, f * 0.6), human=0.0)
	return s.render(echo_beats=0.5, room=0.78)

# ---------------------------------------------------------------- music: chapter 2 terrace (sunny future-bass bossa)


def song_terrace():
	s = Song(124, 16)
	s.bus("kick", gain=0.85, rev=0.0)
	s.bus("perc", pan=0.25, gain=0.38, rev=0.15)
	s.bus("clap", pan=-0.05, gain=0.42, rev=0.2)
	s.bus("bass", gain=0.6, rev=0.0, pump=0.55)
	s.bus("chords", gain=0.38, rev=0.35, pump=0.8)
	s.bus("guitar", pan=-0.35, gain=0.32, rev=0.25)
	s.bus("lead", pan=0.1, gain=0.34, rev=0.3, echo=0.3)
	s.bus("sparkle", pan=0.4, gain=0.16, rev=0.4, echo=0.3)
	A = ("A2", ["A3", "C#4", "E4", "B4"])
	E = ("E2", ["G#3", "B3", "E4", "F#4"])
	Fm = ("F#2", ["A3", "C#4", "E4", "F#4"])
	D = ("D2", ["A3", "D4", "F#4", "C#5"])
	Bm = ("B1", ["A3", "B3", "D4", "F#4"])
	Cm = ("C#2", ["G#3", "C#4", "E4", "B4"])
	chords = [A, E, Fm, D, A, E, D, D, Bm, Cm, D, E, Fm, Cm, D, E]
	melody = [
		[(0, .5, "E5"), (.5, .5, "C#5"), (1, .5, "E5"), (1.5, 1, "A5"), (3, .5, "G#5"), (3.5, .5, "F#5")],
		[(0, 1.5, "G#5"), (1.5, .5, "E5"), (2, 1, "B4"), (3, .5, "E5"), (3.5, .5, "F#5")],
		[(0, 1, "A5"), (1, .5, "G#5"), (1.5, .5, "F#5"), (2, 1, "E5"), (3, 1, "C#5")],
		[(0, 1.5, "D5"), (1.5, .5, "E5"), (2, 2, "F#5")],
		[(0, .5, "E5"), (.5, .5, "C#5"), (1, .5, "E5"), (1.5, 1, "A5"), (3, .5, "B5"), (3.5, .5, "C#6")],
		[(0, 1, "B5"), (1, 1, "G#5"), (2, .5, "E5"), (2.5, .5, "F#5"), (3, 1, "G#5")],
		[(0, 1.5, "A5"), (1.5, .5, "F#5"), (2, 1, "D5"), (3, 1, "E5")],
		[(0, 2, "F#5"), (2, .5, "E5"), (2.5, .5, "D5"), (3, 1, "C#5")],
		[(0, .5, "D5"), (.5, .5, "F#5"), (1, 1, "B5"), (2, .5, "A5"), (2.5, .5, "F#5"), (3, 1, "D5")],
		[(0, .5, "E5"), (.5, .5, "G#5"), (1, 1, "C#6"), (2, 1, "B5"), (3, 1, "G#5")],
		[(0, 1, "A5"), (1, .5, "F#5"), (1.5, .5, "A5"), (2, 1.5, "D6"), (3.5, .5, "C#6")],
		[(0, 1.5, "B5"), (1.5, .5, "G#5"), (2, 2, "E5")],
		[(0, .5, "C#6"), (.5, .5, "B5"), (1, .5, "A5"), (1.5, .5, "F#5"), (2, 1, "A5"), (3, 1, "C#6")],
		[(0, 1.5, "B5"), (1.5, .5, "G#5"), (2, 1, "E5"), (3, 1, "G#5")],
		[(0, 1, "F#5"), (1, 1, "A5"), (2, 1, "D6"), (3, 1, "C#6")],
		[(0, 1.5, "B5"), (1.5, .5, "G#5"), (2, 1, "E5"), (3, .5, "D5"), (3.5, .5, "E5")],
	]
	for bar, (root, voicing) in enumerate(chords):
		r = hz(root)
		for b in range(4):
			s.add("bass", s.t(bar, b), synbass(r if b != 2 else r * 2.0, 0.85 * s.spb, 0.8, cut0=1400.0, cut1=260.0, fdec=0.12), human=0.0)
			for note in voicing:
				s.add("chords", s.t(bar, b), pad(hz(note), 0.9 * s.spb, 0.55, cut=3200.0, attack=0.01, release=0.12, detune=0.009), human=0.0)
		comp = [0.5, 1.5, 2.0, 3.0] if bar % 2 == 0 else [0.0, 1.0, 2.5, 3.5]
		for h in comp:
			for v, note in enumerate(voicing[:3]):
				s.add("guitar", s.t(bar, h) + v * 0.01, pluck(hz(note), 0.35, 0.5, bright=0.55, decay=0.996))
		if bar >= 8:
			tones = [hz(x) * 2.0 for x in voicing]
			for k in range(8):
				s.add("sparkle", s.t(bar, k * 0.5), bell(tones[k % len(tones)], 0.45, length=0.3), human=0.0)
	for bar, notes in enumerate(melody):
		for b, d, note in notes:
			s.add("lead", s.t(bar, b), bell(hz(note), 0.7, length=0.5), human=0.0)
			s.add("lead", s.t(bar, b), lead(hz(note), d * s.spb * 0.85, 0.35, duty=0.5, cut=2600.0), human=0.0)
	for bar in range(16):
		for b in range(4):
			s.add("kick", s.t(bar, b), kick(0.95, punch=100.0, base=48.0, length=0.24), human=0.0)
		for b in (1, 3):
			s.add("clap", s.t(bar, b), clap(0.8), human=0.0)
		for e in range(8):
			s.add("perc", s.t(bar, e * 0.5 + 0.0), shaker(0.4 if e % 2 else 0.22))
		for b in ([0, 1.5, 3] if bar % 2 == 0 else [1, 2]):
			s.add("perc", s.t(bar, b), rim(0.35, 1500.0))
	return s.render(echo_beats=0.75, room=0.8)

# ---------------------------------------------------------------- music: chapter 2 boss (electronic rock + alarms)


def gear(vel=0.6):
	return seq((0, metal([620.0, 1310.0, 2290.0], 0.07, vel), 0.8), (0, noise_burst(0.03, hp=2000, dec=0.01), 0.4))


def song_boss2():
	s = Song(150, 16)
	s.bus("kick", gain=0.95, rev=0.0)
	s.bus("snare", pan=0.05, gain=0.55, rev=0.18)
	s.bus("hat", pan=0.35, gain=0.2, rev=0.05)
	s.bus("gear", pan=-0.4, gain=0.3, rev=0.2)
	s.bus("bass", gain=0.55, rev=0.0, drive=2.5)
	s.bus("guitar", pan=-0.25, gain=0.32, rev=0.15, drive=4.0)
	s.bus("guitar2", pan=0.25, gain=0.32, rev=0.15, drive=4.0)
	s.bus("lead", pan=0.05, gain=0.3, rev=0.25, echo=0.25)
	s.bus("alarm", pan=0.3, gain=0.18, rev=0.35)
	s.bus("crash", pan=0.2, gain=0.28, rev=0.25)
	chords = ["E2", "E2", "C2", "D2", "E2", "E2", "A1", "B1", "C2", "D2", "E2", "G2", "C2", "D2", "B1", "B1"]
	melody = [
		[(0, 1, "E5"), (1, .5, "G5"), (1.5, .5, "F#5"), (2, 1, "E5"), (3, 1, "B4")],
		[(0, 1.5, "D5"), (1.5, .5, "E5"), (2, 2, "B4")],
		[(0, 1, "C5"), (1, .5, "E5"), (1.5, .5, "G5"), (2, 1, "A5"), (3, 1, "G5")],
		[(0, 1.5, "F#5"), (1.5, .5, "E5"), (2, 1, "D5"), (3, 1, "F#5")],
		[(0, 1, "B5"), (1, .5, "A5"), (1.5, .5, "G5"), (2, 1, "E5"), (3, 1, "G5")],
		[(0, 1.5, "F#5"), (1.5, .5, "G5"), (2, 2, "E5")],
		[(0, 1, "A5"), (1, 1, "C6"), (2, 1, "B5"), (3, 1, "A5")],
		[(0, 2, "B5"), (2, 1, "A5"), (3, 1, "F#5")],
		[(0, 1, "G5"), (1, 1, "E5"), (2, 1, "C5"), (3, 1, "E5")],
		[(0, 1, "F#5"), (1, 1, "A5"), (2, 2, "D6")],
		[(0, 1, "E6"), (1, .5, "D6"), (1.5, .5, "B5"), (2, 1, "G5"), (3, 1, "E5")],
		[(0, 1, "D6"), (1, 1, "B5"), (2, 2, "G5")],
		[(0, 1, "E5"), (1, 1, "G5"), (2, 1, "C6"), (3, 1, "E6")],
		[(0, 1.5, "D6"), (1.5, .5, "C6"), (2, 1, "A5"), (3, 1, "F#5")],
		[(0, 1, "D#5"), (1, 1, "F#5"), (2, 1, "B5"), (3, 1, "A5")],
		[(0, 2, "B5"), (2, 1, "F#5"), (3, 1, "D#5")],
	]
	for bar, root in enumerate(chords):
		r = hz(root)
		for e in range(8):
			s.add("bass", s.t(bar, e * 0.5), synbass(r, 0.45 * s.spb, 0.9, cut0=1500.0, cut1=300.0, fdec=0.05), human=0.0)
			chug = 0.42 * s.spb if e % 4 != 3 else 0.9 * s.spb
			for mult in (2.0, 3.0, 4.0):
				s.add("guitar", s.t(bar, e * 0.5), lead(r * mult, chug, 0.55, cut=2400.0, vib=0.0, saw=True), human=0.002)
				s.add("guitar2", s.t(bar, e * 0.5) + 0.012, lead(r * mult * 1.003, chug, 0.5, cut=2200.0, vib=0.0, saw=True), human=0.002)
		if bar in (0, 8):
			s.add("crash", s.t(bar, 0), crash(0.8, 1.6))
			for k in range(4):
				s.add("alarm", s.t(bar, k), lead(988.0 if k % 2 == 0 else 784.0, 0.9 * s.spb, 0.6, duty=0.5, cut=3000.0, vib=0.0), human=0.0)
	for bar, notes in enumerate(melody):
		for b, d, note in notes:
			s.add("lead", s.t(bar, b), lead(hz(note), d * s.spb * 0.92, 0.7, cut=3600.0, saw=True), human=0.0)
	for bar in range(16):
		for b in (0, 1.5, 2, 3.5) if bar % 4 != 3 else (0, 0.5, 1.5, 2, 2.5, 3, 3.5):
			s.add("kick", s.t(bar, b), kick(1.0, punch=120.0, base=52.0, length=0.2), human=0.0)
		for b in (1, 3):
			s.add("snare", s.t(bar, b), snare(0.95, tone=200.0, snap=0.15), human=0.0)
		for k in range(8):
			s.add("hat", s.t(bar, k * 0.5), hat(0.5 if k % 2 == 0 else 0.3, 0.03), human=0.0)
		for b in (0.75, 2.75):
			s.add("gear", s.t(bar, b), gear(0.5), human=0.0)
		if bar == 15:
			for k in range(8):
				s.add("snare", s.t(bar, 2 + k * 0.25), snare(0.3 + 0.08 * k), human=0.0)
	return s.render(echo_beats=0.5, room=0.75)

# ---------------------------------------------------------------- sound effects


def sweep_tone(f0, f1, dur, att=0.002, dec=None, shape="sine", vol=1.0, curve="exp", vib=0.0, vib_hz=0.0):
	n = at(dur)
	out = [0.0] * n
	ph = 0.0
	dec = dec or dur * 0.5
	k = decay_k(dec)
	a = vol
	att_n = max(1, at(att))
	for i in range(n):
		x = i / n
		f = f0 * (f1 / f0) ** x if curve == "exp" else f0 + (f1 - f0) * x
		if vib:
			f *= 1.0 + vib * sin(TAU * vib_hz * i / SR)
		dt = f / SR
		if shape == "sine":
			v = sin(TAU * ph)
		elif shape == "square":
			v = (1.0 if ph < 0.5 else -1.0) + blep(ph, dt) - blep(ph - 0.5 if ph >= 0.5 else ph + 0.5, dt)
		elif shape == "tri":
			v = 4.0 * abs(ph - 0.5) - 1.0
		else:
			v = 2.0 * ph - 1.0 - blep(ph, dt)
		ph += dt
		if ph >= 1.0:
			ph -= 1.0
		env = min(1.0, i / att_n) * a
		out[i] = v * env
		a *= k
	return fade_tail(out, 0.004)


def noise_burst(dur, lp=None, hp=None, att=0.002, dec=None, vol=1.0, lp_end=None):
	n = at(dur)
	nz = [noise() for _ in range(n)]
	if lp_end:
		s = 0.0
		for i in range(n):
			c = lp * (lp_end / lp) ** (i / n)
			a = min(1.0, TAU * c / SR)
			s += a * (nz[i] - s)
			nz[i] = s
	elif lp:
		nz = lowpass(nz, lp)
	if hp:
		nz = highpass(nz, hp)
	dec = dec or dur * 0.35
	k = decay_k(dec)
	a = vol
	att_n = max(1, at(att))
	for i in range(n):
		nz[i] *= min(1.0, i / att_n) * a
		a *= k
	return fade_tail(nz, 0.004)


def chime(freq, vol=0.6, life=0.5):
	return bell(freq, vol, length=life, partials=((1.0, 1.0, 1.0), (2.76, 0.32, 0.4), (5.4, 0.12, 0.18)))


def metal(freqs, life, vol=0.5):
	n = at(life * 3)
	out = [0.0] * n
	for j, f in enumerate(freqs):
		a = vol / (1 + j * 0.4)
		k = decay_k(life / (1 + j * 0.5))
		w = TAU * f / SR
		for i in range(n):
			out[i] += a * sin(w * i)
			a *= k
	return fade_tail(out, 0.02)


def seq(*parts):
	"""parts: (offset_seconds, samples, gain)"""
	out = []
	for off, smp, g in parts:
		mixin(out, smp, at(off), g)
	return out


def sfx_all():
	S = {}
	S["click"] = seq((0, sweep_tone(1900, 1400, 0.03, dec=0.008), 0.8), (0, noise_burst(0.006, hp=3000, dec=0.002), 0.3))
	S["select"] = seq((0, sweep_tone(650, 1350, 0.07, dec=0.04), 0.8), (0.012, sweep_tone(1300, 2700, 0.05, dec=0.03), 0.25))
	S["deny"] = lowpass(seq((0, sweep_tone(230, 220, 0.075, dec=0.05, shape="square"), 0.5), (0.1, sweep_tone(180, 170, 0.09, dec=0.06, shape="square"), 0.5)), 1600)
	S["page"] = noise_burst(0.17, lp=1500, lp_end=5500, hp=700, att=0.03, dec=0.06)
	S["toggle"] = seq((0, sweep_tone(880, 880, 0.06, dec=0.03), 0.6), (0.07, sweep_tone(1320, 1320, 0.09, dec=0.05), 0.6))
	S["deploy"] = seq((0, sweep_tone(950, 430, 0.07, dec=0.05), 0.9), (0, sweep_tone(140, 90, 0.12, dec=0.05), 0.6),
		(0.035, chime(2093, 0.5, 0.25), 0.5), (0.07, chime(3136, 0.3, 0.2), 0.35))
	S["remove"] = seq((0, noise_burst(0.3, lp=4500, lp_end=500, att=0.02, dec=0.12), 0.8), (0, sweep_tone(650, 240, 0.25, dec=0.12), 0.35))
	S["collect"] = seq((0, chime(1318.5, 0.7, 0.35), 0.8), (0.075, chime(1975.5, 0.7, 0.45), 0.9),
		(0.0, noise_burst(0.25, hp=6000, att=0.01, dec=0.08), 0.12))
	S["produce"] = seq((0, chime(1046.5, 0.5, 0.4), 0.6), (0.045, chime(1318.5, 0.5, 0.4), 0.6), (0.09, chime(1568, 0.5, 0.5), 0.6),
		(0, noise_burst(0.4, hp=7000, att=0.05, dec=0.12), 0.1))
	S["supply"] = seq((0, noise_burst(0.012, hp=1500, dec=0.004), 0.7), (0.03, noise_burst(0.02, hp=2500, dec=0.006), 0.5),
		(0.06, chime(2637, 0.7, 0.5), 0.8), (0.06, chime(3520, 0.5, 0.45), 0.6), (0.18, chime(2637, 0.4, 0.3), 0.3))
	S["shot_gpt"] = lowpass(seq((0, sweep_tone(1600, 520, 0.11, dec=0.06, shape="square"), 0.45), (0, sweep_tone(1650, 600, 0.11, dec=0.06), 0.5)), 5200)
	S["shot_water"] = seq((0, sweep_tone(260, 760, 0.12, att=0.005, dec=0.06, vib=0.08, vib_hz=38), 0.8), (0.01, noise_burst(0.1, lp=2200, dec=0.04), 0.3))
	S["shot_gemini"] = seq((0, sweep_tone(2300, 1100, 0.07, dec=0.035), 0.6), (0.045, sweep_tone(2600, 1300, 0.07, dec=0.035), 0.55),
		(0.02, chime(3520, 0.3, 0.12), 0.25))
	S["shot_qwen"] = seq((0, noise_burst(0.2, lp=7000, hp=1500, att=0.045, dec=0.06), 0.9), (0.05, metal([3200, 4870], 0.06, 0.4), 0.4))
	S["shot_grok"] = seq((0, sweep_tone(230, 80, 0.16, dec=0.08), 1.0), (0, noise_burst(0.12, lp=1300, dec=0.05), 0.6),
		(0, lowpass(sweep_tone(460, 210, 0.09, dec=0.05, shape="square"), 2500), 0.35))
	S["scan"] = seq((0, sweep_tone(300, 1800, 0.38, att=0.02, dec=0.5, vib=0.04, vib_hz=18), 0.55), (0.36, chime(2400, 0.5, 0.25), 0.5))
	S["hit"] = seq((0, sweep_tone(560, 250, 0.05, dec=0.025), 0.85), (0, noise_burst(0.01, lp=3200, dec=0.004), 0.5))
	S["hit_water"] = seq((0, noise_burst(0.13, lp=2600, dec=0.05), 0.75), (0, sweep_tone(900, 380, 0.06, dec=0.03), 0.35))
	S["hit_shield"] = seq((0, metal([2100, 5260, 7400], 0.09, 0.6), 0.9), (0, noise_burst(0.008, hp=3000, dec=0.003), 0.4))
	S["shield_break"] = seq((0, metal([1240, 2730, 4190, 5650], 0.25, 0.6), 0.8), (0, noise_burst(0.35, hp=1800, dec=0.12), 0.6),
		(0, sweep_tone(140, 70, 0.15, dec=0.07), 0.6), (0.06, metal([1860, 3310], 0.15, 0.4), 0.5))
	S["boom"] = seq((0, sweep_tone(150, 42, 0.45, dec=0.18), 1.0), (0, noise_burst(0.5, lp=1800, lp_end=250, dec=0.2), 0.8),
		(0.0, noise_burst(0.02, hp=2000, dec=0.006), 0.4))
	S["block"] = seq((0, sweep_tone(170, 90, 0.12, dec=0.05), 0.9), (0, noise_burst(0.07, lp=2600, dec=0.025), 0.45))
	S["bite"] = lowpass(seq((0, sweep_tone(190, 160, 0.05, dec=0.025, shape="square"), 0.5), (0.07, sweep_tone(150, 120, 0.06, dec=0.03, shape="square"), 0.5)), 1000)
	S["kill"] = seq((0, noise_burst(0.3, lp=1900, lp_end=600, att=0.006, dec=0.1), 0.8), (0.005, sweep_tone(420, 1150, 0.05, dec=0.03), 0.55),
		(0.05, chime(1760, 0.4, 0.22), 0.35))
	tinks = [(rng.uniform(0, 0.3), metal([rng.uniform(2000, 6000), rng.uniform(3000, 7500)], 0.05, 0.4), rng.uniform(0.2, 0.5)) for _ in range(10)]
	S["lost"] = seq((0, noise_burst(0.45, hp=1500, dec=0.14), 0.7), (0, sweep_tone(130, 60, 0.18, dec=0.07), 0.7), *tinks)
	S["wave"] = seq((0, chime(1760, 0.8, 0.6), 0.9), (0.07, chime(2093, 0.7, 0.55), 0.75), (0.15, chime(1760, 0.6, 0.5), 0.6),
		(0.26, chime(2093, 0.5, 0.5), 0.45), (0.4, chime(1760, 0.35, 0.45), 0.3))
	dong = lambda f: bell(f, 0.8, length=0.8, partials=((1.0, 1.0, 1.0), (2.0, 0.3, 0.5), (3.0, 0.15, 0.3), (4.2, 0.08, 0.2)))
	S["last_wave"] = seq((0, dong(659.3), 0.8), (0.2, dong(523.3), 0.8), (0.42, dong(659.3), 0.8), (0.62, dong(523.3), 0.8))
	alarm = lowpass(seq((0.25, sweep_tone(740, 740, 0.17, dec=0.5, shape="square"), 0.35), (0.43, sweep_tone(587, 587, 0.17, dec=0.5, shape="square"), 0.35),
		(0.61, sweep_tone(740, 740, 0.17, dec=0.5, shape="square"), 0.3), (0.79, sweep_tone(587, 587, 0.2, dec=0.3, shape="square"), 0.25)), 2600)
	S["boss_phase"] = seq((0, sweep_tone(85, 40, 0.5, dec=0.22), 1.0), (0, metal([330, 870, 1460], 0.45, 0.5), 0.6),
		(0, noise_burst(0.3, lp=1200, dec=0.1), 0.6), (0, alarm, 1.0))
	S["warning"] = lowpass(seq((0, sweep_tone(1046, 1046, 0.065, dec=0.2, shape="square"), 0.4), (0.12, sweep_tone(1046, 1046, 0.065, dec=0.2, shape="square"), 0.4)), 3200)
	S["seal"] = seq((0, sweep_tone(115, 55, 0.12, dec=0.05), 1.0), (0, noise_burst(0.07, lp=1300, dec=0.025), 0.7), (0.005, sweep_tone(420, 380, 0.04, dec=0.015), 0.4))
	S["megaphone"] = lowpass(highpass(seq((0, sweep_tone(330, 300, 0.32, att=0.02, dec=0.4, shape="saw", vib=0.03, vib_hz=7), 0.6),
		(0.34, sweep_tone(300, 260, 0.2, att=0.02, dec=0.15, shape="saw", vib=0.03, vib_hz=7), 0.55)), 400), 1900)
	tick = lambda f: seq((0, noise_burst(0.006, hp=2500, dec=0.002), 0.6), (0, sweep_tone(f, f, 0.02, dec=0.006), 0.6))
	S["hurry"] = seq((0, tick(2600), 0.8), (0.11, tick(2100), 0.8), (0.22, tick(2600), 0.8), (0.33, tick(2100), 0.6))
	S["reveal"] = seq((0, chime(2637, 0.4, 0.3), 0.6), (0.04, chime(2349, 0.4, 0.3), 0.6), (0.08, chime(1976, 0.4, 0.3), 0.6),
		(0.12, chime(1760, 0.4, 0.35), 0.6), (0, noise_burst(0.4, hp=7000, att=0.05, dec=0.15), 0.12))
	whirr = sweep_tone(105, 190, 0.85, att=0.06, dec=2.0, shape="saw", vib=0.06, vib_hz=23)
	S["sweep"] = seq((0, sweep_tone(1200, 1200, 0.05, dec=0.03), 0.4), (0.07, sweep_tone(1600, 1600, 0.06, dec=0.03), 0.4),
		(0.1, fade_tail(lowpass(whirr, 1400), 0.25), 0.7), (0.1, fade_tail(noise_burst(0.85, lp=900, att=0.06, dec=2.0), 0.25), 0.4))
	win = []
	for k, note in enumerate(("C5", "F5", "A5", "C6")):
		mixin(win, ep(hz(note), 0.16, 0.7, release=0.2), at(k * 0.11), 0.8)
		mixin(win, chime(hz(note) * 2, 0.4, 0.4), at(k * 0.11), 0.3)
	for note in ("F4", "A4", "C5", "F5"):
		mixin(win, ep(hz(note), 1.1, 0.6, release=0.6), at(0.46), 0.55)
	mixin(win, chime(hz("F6"), 0.5, 0.8), at(0.46), 0.4)
	mixin(win, chime(hz("A6"), 0.4, 0.8), at(0.56), 0.3)
	mixin(win, chime(hz("C7"), 0.3, 0.8), at(0.66), 0.25)
	S["win"] = win
	lose = []
	for k, note in enumerate(("G4", "F#4", "F4")):
		mixin(lose, ep(hz(note), 0.2, 0.6, release=0.15), at(k * 0.24), 0.8)
	mixin(lose, lead(hz("E4"), 0.75, 0.5, cut=1800.0, vib=0.025), at(0.72), 0.55)
	mixin(lose, ep(hz("E4"), 0.75, 0.5, release=0.4), at(0.72), 0.5)
	mixin(lose, sweep_tone(110, 55, 0.4, dec=0.15), at(0.72), 0.4)
	S["lose"] = lose
	S["star"] = seq((0, chime(hz("C6"), 0.7, 0.55), 0.8), (0.04, chime(hz("G6"), 0.5, 0.5), 0.5), (0, noise_burst(0.3, hp=7500, att=0.02, dec=0.1), 0.12))
	# ---- 第 02 章
	S["shot_ice"] = seq((0, sweep_tone(3000, 1700, 0.07, dec=0.035), 0.6), (0, metal([4200, 6100], 0.05, 0.5), 0.5), (0, noise_burst(0.08, hp=5000, dec=0.03), 0.3))
	crackles = [(rng.uniform(0, 0.35), metal([rng.uniform(3500, 7000)], 0.03, 0.5), rng.uniform(0.2, 0.5)) for _ in range(9)]
	S["freeze"] = seq((0, sweep_tone(320, 140, 0.25, dec=0.1), 0.6), (0, noise_burst(0.4, hp=4000, att=0.01, dec=0.12), 0.45), *crackles)
	S["whisk"] = seq((0, noise_burst(0.26, lp=900, lp_end=3200, att=0.06, dec=0.08), 0.8), (0.02, sweep_tone(160, 110, 0.1, dec=0.05), 0.4))
	S["aim"] = seq((0, sweep_tone(2000, 2000, 0.04, dec=0.02), 0.5), (0.09, sweep_tone(2400, 2400, 0.05, dec=0.025), 0.5))
	S["flash"] = seq((0, noise_burst(0.015, hp=2000, dec=0.004), 0.9), (0.02, noise_burst(0.02, hp=3000, dec=0.006), 0.6),
		(0.03, sweep_tone(2500, 7000, 0.22, att=0.01, dec=0.12), 0.35), (0.03, noise_burst(0.25, hp=6000, dec=0.08), 0.35))
	buzz = [0.0] * at(0.6)
	for i in range(len(buzz)):
		t = i / SR
		buzz[i] = (2.0 * ((180.0 * t) % 1.0) - 1.0) * (0.6 + 0.4 * sin(TAU * 32.0 * t)) * min(1.0, t / 0.05) * min(1.0, (0.6 - t) / 0.1)
	S["drone"] = lowpass(buzz, 1800)
	S["stamp"] = seq((0, sweep_tone(95, 45, 0.25, dec=0.1), 1.0), (0, noise_burst(0.08, lp=1500, dec=0.03), 0.8),
		(0.18, sweep_tone(1500, 1500, 0.05, dec=0.03), 0.3), (0.26, sweep_tone(1900, 1900, 0.06, dec=0.03), 0.3))
	gated = noise_burst(0.35, hp=1200, dec=0.15)
	for i in range(len(gated)):
		if (i // at(0.018)) % 2:
			gated[i] *= 0.15
	S["emp"] = seq((0, gated, 0.7), (0, lowpass(sweep_tone(900, 90, 0.4, dec=0.2, shape="saw"), 2500), 0.6), (0.02, metal([2800, 4100], 0.08, 0.4), 0.4))
	S["overclock"] = seq((0, lowpass(sweep_tone(200, 900, 0.4, att=0.02, dec=0.6, shape="saw"), 3000), 0.5), (0.38, chime(1760, 0.6, 0.4), 0.7), (0.42, chime(2637, 0.4, 0.3), 0.4))
	S["reverse"] = seq((0, sweep_tone(140, 80, 0.12, dec=0.06), 0.8), (0.02, noise_burst(0.12, hp=1500, dec=0.03), 0.5),
		(0.08, noise_burst(0.45, lp=500, lp_end=3500, att=0.08, dec=0.2), 0.6), (0.35, sweep_tone(880, 880, 0.07, dec=0.04), 0.35), (0.45, sweep_tone(1320, 1320, 0.09, dec=0.05), 0.35))
	rip = noise_burst(0.3, lp=4000, hp=600, att=0.01, dec=0.2)
	for i in range(len(rip)):
		rip[i] *= 0.4 + 0.6 * rng.random()
	S["umbrella_break"] = seq((0, rip, 0.8), (0.12, sweep_tone(300, 120, 0.06, dec=0.02), 0.6), (0.14, noise_burst(0.02, hp=1500, dec=0.006), 0.6))
	S["repair"] = seq((0, metal([1850, 3900], 0.06, 0.6), 0.7), (0.14, metal([2100, 4300], 0.06, 0.6), 0.7), (0.28, chime(1568, 0.5, 0.4), 0.5), (0.34, chime(2093, 0.5, 0.45), 0.5))
	S["blackout"] = seq((0, noise_burst(0.02, hp=1500, dec=0.006), 0.8), (0.02, lowpass(sweep_tone(420, 35, 0.9, att=0.01, dec=0.9, shape="saw"), 1600), 0.8), (0.02, sweep_tone(60, 30, 0.6, dec=0.4), 0.5))
	riser = sweep_tone(80, 320, 2.2, att=1.0, dec=10.0, shape="saw", vib=0.04, vib_hz=9)
	S["charge"] = seq((0, lowpass(riser, 1400), 0.6), (0, noise_burst(2.2, lp=400, lp_end=4000, att=1.6, dec=10.0), 0.35))
	S["interrupt"] = seq((0, metal([1240, 2730, 4190, 5650], 0.3, 0.6), 0.7), (0, noise_burst(0.3, hp=2500, dec=0.1), 0.5), (0.05, sweep_tone(700, 180, 0.3, dec=0.15), 0.5), (0.1, chime(2093, 0.5, 0.5), 0.5))
	S["blast"] = seq((0, sweep_tone(70, 28, 0.9, dec=0.4), 1.0), (0, noise_burst(1.0, lp=2500, lp_end=200, dec=0.4), 0.9), (0, crash(0.6, 1.0), 0.5))
	S["leak"] = seq((0, sweep_tone(659, 659, 0.12, dec=0.08), 0.6), (0.13, sweep_tone(523, 500, 0.22, dec=0.12), 0.6), (0.13, sweep_tone(90, 60, 0.12, dec=0.05), 0.4))
	tear = noise_burst(0.28, lp=5500, hp=900, att=0.005, dec=0.15)
	for i in range(len(tear)):
		tear[i] *= 0.25 + 0.75 * abs(sin(i / SR * 260.0 + rng.random()))
	S["tear"] = tear
	S["coins"] = seq(*[(k * 0.05 + rng.uniform(0, 0.02), metal([rng.uniform(2600, 4800), rng.uniform(5000, 6800)], 0.07, 0.5), 0.6) for k in range(7)])
	S["income_freeze"] = seq((0, noise_burst(0.015, hp=1500, dec=0.005), 0.8), (0.03, lowpass(sweep_tone(220, 200, 0.35, dec=0.3, shape="square"), 1200), 0.4), (0.12, *crackles[0][1:]))
	slurp = noise_burst(0.35, lp=300, lp_end=1600, att=0.05, dec=0.2)
	S["absorb"] = seq((0, slurp, 0.8), (0.12, sweep_tone(300, 700, 0.06, dec=0.03), 0.4), (0.24, sweep_tone(350, 800, 0.06, dec=0.03), 0.4))
	# ---- 第 02 章扩展：新店员与新来客
	S["conch"] = seq((0, lowpass(sweep_tone(220, 260, 0.35, att=0.04, dec=0.4, shape="saw", vib=0.02, vib_hz=6), 1400), 0.6),
		(0, sweep_tone(440, 520, 0.35, att=0.04, dec=0.4, vib=0.02, vib_hz=6), 0.3), (0.05, noise_burst(0.3, lp=1800, att=0.05, dec=0.15), 0.25))
	S["fireball"] = seq((0, noise_burst(0.28, lp=600, lp_end=2400, att=0.02, dec=0.12), 0.8), (0, sweep_tone(180, 90, 0.2, dec=0.1), 0.5),
		*[(rng.uniform(0.02, 0.2), noise_burst(0.008, hp=3000, dec=0.003), 0.4) for _ in range(6)])
	S["brush"] = seq((0, noise_burst(0.18, lp=2500, lp_end=900, hp=400, att=0.03, dec=0.08), 0.8), (0.05, sweep_tone(900, 600, 0.08, dec=0.04), 0.25))
	S["wool"] = seq((0, sweep_tone(300, 160, 0.12, dec=0.05), 0.7), (0, noise_burst(0.1, lp=1200, dec=0.04), 0.5), (0.02, sweep_tone(700, 1100, 0.05, dec=0.02), 0.25))
	S["zap"] = lowpass(seq((0, noise_burst(0.06, hp=2500, dec=0.02), 0.6), (0, sweep_tone(2400, 900, 0.06, dec=0.03, shape="square"), 0.3)), 6000)
	S["paint"] = seq((0, noise_burst(0.3, lp=900, lp_end=2600, att=0.05, dec=0.15), 0.7), (0.1, chime(1568, 0.4, 0.3), 0.4), (0.16, chime(2093, 0.35, 0.3), 0.35))
	S["think"] = seq((0, lowpass(sweep_tone(110, 440, 1.6, att=0.6, dec=5.0, shape="saw", vib=0.03, vib_hz=7), 1500), 0.5),
		(0.2, chime(1318.5, 0.3, 0.4), 0.3), (0.6, chime(1760, 0.3, 0.4), 0.3), (1.0, chime(2349, 0.3, 0.4), 0.3))
	S["beam"] = seq((0, lowpass(sweep_tone(900, 180, 0.6, att=0.005, dec=0.3, shape="saw"), 3500), 0.6), (0, noise_burst(0.5, hp=1500, dec=0.2), 0.5),
		(0, sweep_tone(80, 40, 0.4, dec=0.2), 0.7))
	S["steal"] = seq((0, sweep_tone(1200, 1800, 0.06, dec=0.03), 0.4), (0.07, noise_burst(0.08, lp=3000, dec=0.03), 0.5), (0.1, sweep_tone(600, 300, 0.1, dec=0.05), 0.3))
	return S

# ---------------------------------------------------------------- main


def stats(name, L, R=None):
	both = L + (R or [])
	peak = max(abs(v) for v in both)
	rms = math.sqrt(sum(v * v for v in both) / len(both))
	seam = abs(L[0] - L[-1]) if R else 0.0
	print("%-14s %6.2fs  peak %5.2f dB  rms %6.2f dB%s" % (name, len(L) / SR, 20 * math.log10(peak + 1e-9), 20 * math.log10(rms + 1e-9),
		"  seam %.4f" % seam if R else ""))


def main():
	what = sys.argv[1] if len(sys.argv) > 1 else "all"
	os.makedirs(OUT, exist_ok=True)
	if what in ("all", "sfx"):
		for name, data in sfx_all().items():
			data = normalize(data, 0.89)
			write_wav(os.path.join(OUT, "sfx_%s.wav" % name), data)
			stats("sfx_" + name, data)
	if what in ("all", "music"):
		tmp = tempfile.mkdtemp()
		songs = (("music_menu", song_menu), ("music_battle", song_battle), ("music_boss", song_boss), ("music_terrace", song_terrace), ("music_boss2", song_boss2))
		only = os.environ.get("ONLY")
		for name, fn in songs:
			if only and name not in only.split(","):
				continue
			L, R = fn()
			stats(name, L, R)
			wav_path = os.path.join(tmp, name + ".wav")
			write_wav(wav_path, L, R)
			subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav_path, "-c:a", "libvorbis", "-q:a", "5",
				os.path.join(OUT, name + ".ogg")], check=True)
			if os.environ.get("KEEP_WAV"):
				os.replace(wav_path, os.path.join(os.environ["KEEP_WAV"], name + ".wav"))


if __name__ == "__main__":
	main()
