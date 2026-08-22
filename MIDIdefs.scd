(

MIDIClient.init;
MIDIIn.connectAll;

~midiOut     = nil;
~midiChan    = 0;
~midiCCNums  = [16, 17, 18, 19];
~midiCCActive = [false, false, false, false];

// Manual 1 Mixtur 2 (CC1)
MIDIdef.cc(\manual1mxt2, { |val|
    if(~routeSynths.notNil) {
        if(val == 127) {
            ~routeSynths[0].set(\amp, 0);
            ~routeSynths[1].set(\amp, 1);
            ~routeSynths[2].set(\amp, 0);
            ~updateMixturHighlight.(1, 2);
        } {
            ~routeSynths[0].set(\amp, 1);
            ~routeSynths[1].set(\amp, 0);
            ~routeSynths[2].set(\amp, 0);
            ~updateMixturHighlight.(1, 1);
        };
    };
}, ccNum: 1, chan: 0);

// Manual 1 Mixtur 3 (CC2)
MIDIdef.cc(\manual1mxt3, { |val|
    if(~routeSynths.notNil) {
        if(val == 127) {
            ~routeSynths[0].set(\amp, 0);
            ~routeSynths[1].set(\amp, 0);
            ~routeSynths[2].set(\amp, 1);
            ~updateMixturHighlight.(1, 3);
        } {
            ~routeSynths[0].set(\amp, 1);
            ~routeSynths[1].set(\amp, 0);
            ~routeSynths[2].set(\amp, 0);
            ~updateMixturHighlight.(1, 1);
        };
    };
}, ccNum: 2, chan: 0);

// Manual 2 Mixtur 2 (CC5)
MIDIdef.cc(\manual2mxt2, { |val|
    if(~routeSynths.notNil) {
        if(val == 127) {
            ~routeSynths[3].set(\amp, 0);
            ~routeSynths[4].set(\amp, 1);
            ~routeSynths[5].set(\amp, 0);
            ~updateMixturHighlight.(2, 2);
        } {
            ~routeSynths[3].set(\amp, 1);
            ~routeSynths[4].set(\amp, 0);
            ~routeSynths[5].set(\amp, 0);
            ~updateMixturHighlight.(2, 1);
        };
    };
}, ccNum: 5, chan: 0);

// Manual 2 Mixtur 3 (CC6)
MIDIdef.cc(\manual2mxt3, { |val|
    if(~routeSynths.notNil) {
        if(val == 127) {
            ~routeSynths[3].set(\amp, 0);
            ~routeSynths[4].set(\amp, 0);
            ~routeSynths[5].set(\amp, 1);
            ~updateMixturHighlight.(2, 3);
        } {
            ~routeSynths[3].set(\amp, 1);
            ~routeSynths[4].set(\amp, 0);
            ~routeSynths[5].set(\amp, 0);
            ~updateMixturHighlight.(2, 1);
        };
    };
}, ccNum: 6, chan: 0);

"MIDIdefs geladen.".postln;
)
