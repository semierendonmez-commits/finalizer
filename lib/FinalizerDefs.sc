// FinalizerDefs.sc
// master bus processor SynthDef
// compiled at norns boot, controlled via OSC from mod.lua

FinalizerDefs {
  *initClass {
    StartUp.add {
      SynthDef(\fnl_master, {
        arg in_bus=0, out_bus=0,
            lo_freq=80, lo_gain=0, lo_q=0.7,
            mid_freq=2000, mid_gain=0, mid_q=1.0,
            hi_freq=8000, hi_gain=0, hi_q=0.7,
            eq_on=1,
            thresh=0.25, ratio=0.25,
            atk=0.01, rel=0.1,
            makeup=1.0, comp_on=1,
            ceiling=0.95, lim_on=1,
            width=1.0, amp=1.0, bypass=0;

        var sig, dry, eq, cmp, lim;
        var sl, sr, m, s;

        sig = In.ar(in_bus, 2);
        dry = sig;

        eq = BPeakEQ.ar(sig,
          lo_freq.clip(20, 500),
          lo_q.clip(0.1, 10),
          lo_gain.clip(-18, 18));
        eq = BPeakEQ.ar(eq,
          mid_freq.clip(100, 8000),
          mid_q.clip(0.1, 10),
          mid_gain.clip(-18, 18));
        eq = BPeakEQ.ar(eq,
          hi_freq.clip(1000, 20000),
          hi_q.clip(0.1, 10),
          hi_gain.clip(-18, 18));
        sig = Select.ar(eq_on, [sig, eq]);

        cmp = Compander.ar(sig, sig,
          thresh: thresh.clip(0.001, 1.0),
          slopeAbove: ratio.clip(0.05, 1.0),
          slopeBelow: 1.0,
          clampTime: atk.clip(0.001, 0.5),
          relaxTime: rel.clip(0.01, 2.0));
        cmp = cmp * makeup.clip(0.1, 10.0);
        sig = Select.ar(comp_on, [sig, cmp]);

        sl = sig[0]; sr = sig[1];
        m = (sl + sr) * 0.5;
        s = (sl - sr) * 0.5 * width;
        sig = [m + s, m - s];

        lim = Limiter.ar(sig, ceiling.clip(0.1, 1.0), 0.01);
        sig = Select.ar(lim_on, [sig, lim]);

        sig = sig * amp;
        sig = Select.ar(bypass, [sig, dry]);

        ReplaceOut.ar(out_bus, sig);
      }).add;

      "FinalizerDefs: SynthDef registered".postln;
    };
  }
}
