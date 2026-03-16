// Finalizer.sc
// master bus processor: EQ + compressor + limiter
// installed as a mod - SynthDef compiled at boot, instantiated per script

Finalizer {
  classvar <synth;
  classvar <synthDef;
  classvar <isRunning = false;

  *initClass {
    StartUp.add {
      synthDef = SynthDef(\finalizer, {
        arg in_bus=0, out_bus=0,
            // EQ - 3 band
            eq_lo_freq=80, eq_lo_gain=0, eq_lo_q=0.7,
            eq_mid_freq=2000, eq_mid_gain=0, eq_mid_q=1.0,
            eq_hi_freq=8000, eq_hi_gain=0, eq_hi_q=0.7,
            eq_on=1,
            // Compressor
            comp_thresh=(-12), comp_ratio=4, comp_attack=0.01,
            comp_release=0.1, comp_makeup=0,
            comp_on=1,
            // Limiter
            lim_level=0.95, lim_on=1,
            // Stereo width
            width=1.0,
            // Master
            amp=1.0, bypass=0;

        var sig, sig_l, sig_r;
        var eq_sig, comp_sig, lim_sig;
        var mid, side;
        var gr, dry;

        sig = In.ar(in_bus, 2);

        // -- bypass: keep clean copy --
        dry = sig;

        // -- EQ section (3-band parametric) --
        eq_sig = sig;
        eq_sig = BPeakEQ.ar(eq_sig,
          eq_lo_freq.clip(20, 500), eq_lo_q.clip(0.1, 10), eq_lo_gain.clip(-18, 18));
        eq_sig = BPeakEQ.ar(eq_sig,
          eq_mid_freq.clip(100, 8000), eq_mid_q.clip(0.1, 10), eq_mid_gain.clip(-18, 18));
        eq_sig = BPeakEQ.ar(eq_sig,
          eq_hi_freq.clip(1000, 20000), eq_hi_q.clip(0.1, 10), eq_hi_gain.clip(-18, 18));
        sig = Select.ar(eq_on, [sig, eq_sig]);

        // -- Compressor --
        comp_sig = Compander.ar(sig, sig,
          thresh: comp_thresh.dbamp,
          slopeAbove: comp_ratio.reciprocal,
          slopeBelow: 1.0,
          clampTime: comp_attack.clip(0.001, 0.5),
          relaxTime: comp_release.clip(0.01, 2.0)
        );
        comp_sig = comp_sig * comp_makeup.dbamp;
        sig = Select.ar(comp_on, [sig, comp_sig]);

        // -- Stereo width (mid/side) --
        sig_l = sig[0]; sig_r = sig[1];
        mid  = (sig_l + sig_r) * 0.5;
        side = (sig_l - sig_r) * 0.5 * width;
        sig_l = mid + side;
        sig_r = mid - side;
        sig = [sig_l, sig_r];

        // -- Limiter --
        lim_sig = Limiter.ar(sig, lim_level.clip(0.1, 1.0), 0.01);
        sig = Select.ar(lim_on, [sig, lim_sig]);

        // -- Master volume --
        sig = sig * amp;

        // -- Bypass --
        sig = Select.ar(bypass, [sig, dry]);

        ReplaceOut.ar(out_bus, sig);
      }).add;
    };
  }

  *start { arg target, addAction=\addAfter;
    if(isRunning.not, {
      synth = Synth(\finalizer, [
        \in_bus, 0, \out_bus, 0
      ], target, addAction);
      isRunning = true;
      "Finalizer: started".postln;
    });
  }

  *stop {
    if(isRunning, {
      synth.free;
      synth = nil;
      isRunning = false;
      "Finalizer: stopped".postln;
    });
  }

  *set { arg ... pairs;
    if(synth.notNil, { synth.set(*pairs) });
  }
}
