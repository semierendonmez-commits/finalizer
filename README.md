## finalizer (mod)

master bus processor. EQ + compressor + limiter on every script's output.

```
;install https://github.com/yourusername/finalizer
```

after install: SYSTEM > RESTART (SC engine class needs compilation)

### signal chain

```
script output → 3-band EQ → compressor → stereo width → limiter → DAC
```

### controls (mod menu)

3 pages, K3 to cycle:

**COMP** — on/off, threshold (-48 to 0 dB), ratio (1:1 to 20:1), attack (1-500ms), release (10-2000ms), makeup gain (0 to +24dB)

**EQ** — on/off, 3 parametric bands (lo/mid/hi), each with freq, gain (±18dB), Q

**MASTER** — limiter on/off, ceiling, stereo width (0-200%, 100%=normal, 0%=mono), master volume, bypass

the finalizer inserts after the script's engine via SC's `addAfter`. it uses `ReplaceOut` on bus 0 — completely transparent to the running script. `Compander` for dynamics, `BPeakEQ` for parametric EQ, `Limiter` for brick wall protection.
