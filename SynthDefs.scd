(

SynthDef(\trauti, {
    arg out = 0, pitchBus = 0, pressBus = 2,
        amp = 0, divi = 8, okt = 0, pan = 0, waveform = 3, lagTime = 0.2, detune = 0;
    var sig, freq;
    freq = In.kr(pitchBus) / divi * (detune * 0.01).midiratio * 2.pow(okt);
    sig = Select.ar(waveform, [
        SinOsc.ar(freq),

        //LFTri.ar(freq) nicht weil nicht bandbegrenzt -> aliasing
		DPW3Tri.ar(freq),

        //LFPulse.ar(freq) nicht weil nicht bandbegrenzt -> aliasing
		PulseDPW.ar(freq), //ist allerdings auch nicht zero aliasing
		//Pulse.ar(freq) nicht weil phasendrifts bei zwei stimmen gleicher frequenz beim glissando


		//LFSaw.ar(freq) nicht weil nicht bandbegrenzt -> aliasing
		//Saw.ar(freq), // nicht weil phasendrifts bei zwei stimmen gleicher frequenz beim glissando
		DPW4Saw.ar(freq),
		//SawDPW.ar(freq);
		//BlitB3Saw.ar(freq),

		Blip.ar(freq, (SampleRate.ir * 0.5 / freq).floor)*20,

        WhiteNoise.ar()
		//PinkNoise.ar()
    ]);
    sig = sig * 0.1 * amp * In.kr(pressBus).lag(lagTime);
    sig = Pan2.ar(sig, pan);
    Out.ar(out, sig);
}).add;


SynthDef(\mixturToMaster, {
    arg inBus = 4, outBus = 10, amp = 1, lagTime = 0.1;   //wenn man 2ins 2outs hat, dann ist ~mixturManual1_1 bei 4/5 -> ~masterManual1 ist 10/11. Die Argumente für inBus outBus werden aber eh bei Instanzierung in Abhängigkeit der Hardware gesetzt und spielen keine Rolle
    Out.ar(outBus, In.ar(inBus, 2) * amp.lag(lagTime));
}).add;


SynthDef(\masterToOut, {
    arg inBus = 10, out = 0, mainvol = 1, verbvol = 0, dryWet = 0,
        // decay 0.000909 = 1/1100, entspricht der Knopfstellung 1.0 im Klang-Panel
        freq1 = 320,  decay1 = 0.000909, level1 = 2,
        freq2 = 1000, decay2 = 0.000909, level2 = 0,
        freq3 = 3200, decay3 = 0.000909, level3 = 0,
        lpFreq = 4000, lpMod = 0, pressBus = 0, svfReso = 0, meterIdx = 0;
    var sig, dry, filtered, cutoff, verb;
    sig = In.ar(inBus, 2);
    dry = sig;
    filtered = (Ringz.ar(sig, freq1, decay1) * level1 * 0.05) +
               (Ringz.ar(sig, freq2, decay2) * level2 * 0.05) +
               (Ringz.ar(sig, freq3, decay3) * level3 * 0.05);
    sig = dry.blend(filtered, dryWet);
    cutoff = lpFreq.blend(20000, (In.kr(pressBus) * lpMod).clip(0, 1));
    sig = SVF.ar(sig, cutoff, svfReso, 1, 0, 0, 0);
    verb = JPverb.ar(sig, 2);
    sig = sig + (verb * verbvol);
	sig = sig * mainvol;
    sig = LeakDC.ar(sig);
    SendPeakRMS.kr(sig, 15, 3, "/masterLevel", meterIdx);
    sig = Limiter.ar(sig, 0.95);
    Out.ar(out, sig);
}).add;
"SynthDefs geladen.".postln;
)

