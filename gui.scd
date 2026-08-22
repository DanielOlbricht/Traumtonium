(
var win, tabBtns, panels, makeManualPanel, tabNames, winH, panelH;
var outDevices, inDevices, outMenu, inMenu, numOutBox, numInBox, serialStatus;
var noteNames, hzToNoteCents;
var routeMenu1, routeMenu2, makeRouteItems;
var sensorTask;
var savePreset, loadPreset, refreshPresetList;
var presetList, presetNameField;
var audioSettingsPath, saveAudioSettings, loadAudioSettings;
var midiDestMenu;
var klangKnobs; // klangKnobs[manualIdx] = (freq1:, decay1:, level1:, ..., dryWet:, verbvol:)

tabNames = ["Config", "Mixturen 1", "Klang 1", "Mixturen 2", "Klang 2"];

audioSettingsPath = (thisProcess.nowExecutingPath ?? { "." }).dirname ++ "/audio_settings.scd";

saveAudioSettings = {
    var f = File(audioSettingsPath, "w");
    f.write(outDevices[outMenu.value] ++ "\n");
    f.write(inDevices[inMenu.value] ++ "\n");
    f.write(numOutBox.value.asInteger.asString ++ "\n");
    f.write(numInBox.value.asInteger.asString ++ "\n");
    f.close;
};

loadAudioSettings = {
    if(File.exists(audioSettingsPath) and: { var f = File(audioSettingsPath, "r"); var s = f.readAllString.stripWhiteSpace; f.close; s.size > 0 }) {
        var f, lines, savedOut, savedIn, savedNumOut, savedNumIn, outIdx, inIdx;
        f = File(audioSettingsPath, "r");
        lines = f.readAllString.split($\n).collect(_.stripWhiteSpace);
        f.close;
        savedOut    = lines[0];
        savedIn     = lines[1];
        savedNumOut = lines[2].asInteger;
        savedNumIn  = lines[3].asInteger;
        outIdx = outDevices.detectIndex { |d| d == savedOut };
        inIdx  = inDevices.detectIndex  { |d| d == savedIn  };
        if(outIdx.notNil) { outMenu.value_(outIdx) } { outMenu.value_(0) };
        if(inIdx.notNil)  { inMenu.value_(inIdx)   } { inMenu.value_(0) };
        numOutBox.value_(if(outIdx.notNil) { savedNumOut } { 2 });
        numInBox.value_( if(inIdx.notNil)  { savedNumIn  } { 2 });
    } {
        outMenu.value_(0); inMenu.value_(0);
        numOutBox.value_(2); numInBox.value_(2);
    };
};

noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "H"];

hzToNoteCents = { |hz|
    var midi, note, cents, sign, oct;
    midi  = hz.cpsmidi;
    note  = midi.round.asInteger;
    cents = ((midi - note) * 100).round.asInteger;
    sign  = if(cents >= 0) { "+" } { "" };
    oct   = (note / 12).floor.asInteger - 1; //floor rundet nach unten (ceil nach oben)
    noteNames[note % 12] ++ oct.asString ++ "  " ++ sign ++ cents.asString ++ " ct"
};

outDevices = ServerOptions.outDevices ?? { ServerOptions.devices }; //falls PC nicht unterscheidet zwischen in und out
inDevices  = ServerOptions.inDevices  ?? { ServerOptions.devices }; //Geräten werden alle devices angezeigt

// Fensterhöhe an den verfügbaren Bildschirm anpassen (ohne Menü- und Titelleiste)
winH   = Window.availableBounds.height - 30;
panelH = winH - 32;   // 32 = Höhe der Tab-Leiste

win = Window("Traumtonium", Rect(0, 0, 756, winH))
    .background_(Color.gray(0.85));

//// Tab buttons //////////////////////////////////////////////////////////////
tabBtns = tabNames.collect { |name, i|
    Button(win, Rect(i * 151, 0, 151, 32))
    .states_([
        [name, Color.gray(0.35), Color.gray(0.72)],
        [name, Color.gray(0.10), Color.gray(0.93)]
    ])
};

//// Panels ///////////////////////////////////////////////////////////////////
panels = tabNames.size.collect { |i|
    CompositeView(win, Rect(0, 32, 756, panelH))
    .background_(Color.gray(0.82))
    .visible_(i == 0)
};

tabBtns.do { |btn, i|
    btn.action_({
        tabBtns.do { |b, j| b.value_(if(i == j) { 1 } { 0 }) };
        panels.do  { |p, j| p.visible_(i == j) };
    });
};
tabBtns[0].value_(1);


//// CONFIG PANEL //////////////////////////////////////////////////////////////
{
    var p, y, lc, sc, bc;
    p  = panels[0];
    y  = 20;
    lc = Color.gray(0.15);
    sc = Color.gray(0.35);
    bc = Color.gray(0.72);

    // Audio Setup
    StaticText(p, Rect(20, y, 300, 22)).string_("AUDIO SETUP")
        .stringColor_(sc).font_(Font("Helvetica", 11, true));
    y = y + 28;

    StaticText(p, Rect(20, y, 90, 22)).string_("In Device:").stringColor_(lc);
    inMenu = PopUpMenu(p, Rect(115, y, 320, 22)).items_(inDevices);
    StaticText(p, Rect(450, y, 60, 22)).string_("Kanäle:").stringColor_(lc);
    numInBox = NumberBox(p, Rect(515, y, 50, 22))
        .value_(s.options.numInputBusChannels).clipLo_(1).clipHi_(64)
        .step_(1).scroll_step_(1);
    y = y + 28;

    StaticText(p, Rect(20, y, 90, 22)).string_("Out Device:").stringColor_(lc);
    outMenu = PopUpMenu(p, Rect(115, y, 320, 22)).items_(outDevices);
    StaticText(p, Rect(450, y, 60, 22)).string_("Kanäle:").stringColor_(lc);
    numOutBox = NumberBox(p, Rect(515, y, 50, 22))
        .value_(s.options.numOutputBusChannels).clipLo_(1).clipHi_(64)
        .step_(1).scroll_step_(1);
    y = y + 40;

    loadAudioSettings.();

    Button(p, Rect(20, y, 120, 26)).states_([["Server booten", lc, bc]])
    .action_({
        s.options.outDevice_(outDevices[outMenu.value]);
        s.options.inDevice_(inDevices[inMenu.value]);
        s.options.numOutputBusChannels_(numOutBox.value.asInteger);
        s.options.numInputBusChannels_(numInBox.value.asInteger);
        saveAudioSettings.();
        s.waitForBoot({
            // SynthDefs laden
            (~projPath +/+ "SynthDefs.scd").load;
            s.sync;

            // Buses
            s.newBusAllocators;
            ~pitch1 = Bus.control(s, 1);  ~pitch2 = Bus.control(s, 1);
            ~pitch1.set(2093);  ~pitch2.set(2093);  // Startwert C7, sonst default 0 -> 0Hz -> knackser beim ersten Ton
            ~press1 = Bus.control(s, 1);  ~press2 = Bus.control(s, 1);
            ~mixturManual1_1 = Bus.audio(s, 2);  ~mixturManual1_2 = Bus.audio(s, 2);
            ~mixturManual1_3 = Bus.audio(s, 2);  ~masterManual1   = Bus.audio(s, 2);
            ~mixturManual2_1 = Bus.audio(s, 2);  ~mixturManual2_2 = Bus.audio(s, 2);
            ~mixturManual2_3 = Bus.audio(s, 2);  ~masterManual2   = Bus.audio(s, 2);
            { makeRouteItems.(numOutBox.value.asInteger) }.defer;
            "Buses erstellt.".postln;

            // Synths
            ~synths.do      { |syn| syn.free };
            ~routeSynths.do { |syn| syn.free };
            ~synths = Array.newClear(30);

            {
                // Global, weil ~rebuildVoices die Stimmen spaeter neu aufbaut
                ~outBuses = (
                    Array.fill(5, ~mixturManual1_1) ++ Array.fill(5, ~mixturManual1_2) ++
                    Array.fill(5, ~mixturManual1_3) ++ Array.fill(5, ~mixturManual2_1) ++
                    Array.fill(5, ~mixturManual2_2) ++ Array.fill(5, ~mixturManual2_3)
                );
                ~pitchIdxs = Array.fill(15, ~pitch1.index) ++ Array.fill(15, ~pitch2.index);
                ~pressIdxs = Array.fill(15, ~press1.index) ++ Array.fill(15, ~press2.index);

                30.do { |i|
                    ~synths[i] = Synth(\trauti, [
                        \out, ~outBuses[i], \pitchBus, ~pitchIdxs[i], \pressBus, ~pressIdxs[i]
                    ], s, \addToTail);
                };

                ~routeSynths = [
                    Synth(\mixturToMaster, [\inBus, ~mixturManual1_1.index, \outBus, ~masterManual1.index], s, \addToTail),
                    Synth(\mixturToMaster, [\inBus, ~mixturManual1_2.index, \outBus, ~masterManual1.index], s, \addToTail),
                    Synth(\mixturToMaster, [\inBus, ~mixturManual1_3.index, \outBus, ~masterManual1.index], s, \addToTail),
                    Synth(\mixturToMaster, [\inBus, ~mixturManual2_1.index, \outBus, ~masterManual2.index], s, \addToTail),
                    Synth(\mixturToMaster, [\inBus, ~mixturManual2_2.index, \outBus, ~masterManual2.index], s, \addToTail),
                    Synth(\mixturToMaster, [\inBus, ~mixturManual2_3.index, \outBus, ~masterManual2.index], s, \addToTail),
                    Synth(\masterToOut, [\inBus, ~masterManual1.index, \out, 0, \pressBus, ~press1.index, \meterIdx, 0], s, \addToTail),
                    Synth(\masterToOut, [\inBus, ~masterManual2.index, \out, 0, \pressBus, ~press2.index, \meterIdx, 1], s, \addToTail)
                ];
                ~routeSynths[1].set(\amp, 0);
                ~routeSynths[2].set(\amp, 0);
                ~routeSynths[4].set(\amp, 0);
                ~routeSynths[5].set(\amp, 0);
                "30 Synths + Routing erstellt.".postln;
            }.value;
        });
    });

    Button(p, Rect(150, y, 90, 26)).states_([["Testton", lc, bc]])
    .action_({ ().play });

    y = y + 55;

    // Output Routing
    StaticText(p, Rect(20, y, 300, 22)).string_("OUTPUT ROUTING")
        .stringColor_(sc).font_(Font("Helvetica", 11, true));
    y = y + 28;

    makeRouteItems = { |numCh|
        var items = [];
        var pairs = (numCh / 2).floor.asInteger;
        pairs.do { |i| items = items.add((i*2+1).asString ++ "/" ++ (i*2+2).asString) };
        routeMenu1.items_(items);
        routeMenu2.items_(items);
    };

    StaticText(p, Rect(20, y, 70, 22)).string_("Manual 1:").stringColor_(lc);
    routeMenu1 = PopUpMenu(p, Rect(95, y, 90, 22)).items_(["1/2"])
    .action_({ |m|
        if(~routeSynths.notNil) { ~routeSynths[6].set(\out, m.value * 2) }
    });

    StaticText(p, Rect(205, y, 70, 22)).string_("Manual 2:").stringColor_(lc);
    routeMenu2 = PopUpMenu(p, Rect(280, y, 90, 22)).items_(["1/2"])
    .action_({ |m|
        if(~routeSynths.notNil) { ~routeSynths[7].set(\out, m.value * 2) }
    });

    y = y + 55;

    // Serial Port
    StaticText(p, Rect(20, y, 300, 22)).string_("SERIAL PORT")
        .stringColor_(sc).font_(Font("Helvetica", 11, true));
    y = y + 28;


    serialStatus = StaticText(p, Rect(20, y, 200, 24))
        .string_("● Traumtonium getrennt").stringColor_(Color(0.7, 0.1, 0.1));

    Button(p, Rect(230, y, 100, 26)).states_([["Verbinden", lc, bc]])
    .action_({
        if(~startSerial.()) {
            serialStatus.string_("● Traumtonium verbunden").stringColor_(Color(0.1, 0.5, 0.1));
        } {
            serialStatus.string_("● Traumtonium nicht gefunden").stringColor_(Color(0.75, 0.45, 0));
        };
    });

    Button(p, Rect(340, y, 80, 26)).states_([["Trennen", lc, Color.gray(0.75)]])
    .action_({
        ~stopSerial.();
        serialStatus.string_("● Traumtonium getrennt").stringColor_(Color(0.7, 0.1, 0.1));
    });

    ~serialPost = false;
    Button(p, Rect(450, y, 110, 26))
    .states_([
        ["Post: OFF", lc, Color.gray(0.75)],
        ["Post: ON",  Color.white, Color(0.15, 0.45, 0.15)]
    ])
    .action_({ |btn| ~serialPost = (btn.value == 1) });

    y = y + 55;

    // MIDI CC auf SystemClock (echtzeit ist wichtig, keine GUI-Interaktion)
    ~midiTask = Task({
        loop {
            0.01.wait;
            if(~midiOut.notNil and: { ~lastReceived.notNil } and: { (Main.elapsedTime - ~lastReceived) < 0.2 }) {
                if(~midiCCActive[0] and: { ~pitch1.notNil }) { ~midiOut.control(~midiChan, ~midiCCNums[0], ~pitch1.getSynchronous.linlin(1046.50, 4186.01, 0, 127).clip(0, 127).round.asInteger) };
                if(~midiCCActive[1] and: { ~press1.notNil }) { ~midiOut.control(~midiChan, ~midiCCNums[1], (~press1.getSynchronous * 127).clip(0, 127).round.asInteger) };
                if(~midiCCActive[2] and: { ~pitch2.notNil }) { ~midiOut.control(~midiChan, ~midiCCNums[2], ~pitch2.getSynchronous.linlin(1046.50, 4186.01, 0, 127).clip(0, 127).round.asInteger) };
                if(~midiCCActive[3] and: { ~press2.notNil }) { ~midiOut.control(~midiChan, ~midiCCNums[3], (~press2.getSynchronous * 127).clip(0, 127).round.asInteger) };
            };
        }
    }).play(SystemClock);


    ~silentSince = [nil, nil];
    ~voicesDirty = [false, false];

    sensorTask = Task({
        loop {
            0.05.wait;
            {
                var p1, p2;

                2.do { |manual|
                    var pressBus = if(manual == 0) { ~press1 } { ~press2 };
                    var lagT = klangKnobs[manual] !? { |k| k[\lagPressKnob].value } ?? 0.2;
                    if(pressBus.notNil) {
                        if(pressBus.getSynchronous > 0.005) {
                            ~silentSince[manual] = nil;   // Ton laeuft
                        } {
                            if(~silentSince[manual].isNil) {
                                ~silentSince[manual] = Main.elapsedTime;
                            };
                            // Lag braucht lagTime fuer 60 dB Abfall, danach Reserve
                            if(~voicesDirty[manual]
                                and: { (Main.elapsedTime - ~silentSince[manual]) > (lagT + 0.3) }) {
                                ~rebuildVoices.(manual);
                                ~voicesDirty[manual] = false;
                            };
                        };
                    };
                };

                p1 = ~pitch1 !? { ~pitch1.getSynchronous };
                p2 = ~pitch2 !? { ~pitch2.getSynchronous };
                if(~manualControls.notNil and: { p1.notNil or: { p2.notNil } }) {
                    30.do { |i|
                        var c = ~manualControls[i];
                        var nd = ~noteDisps[i];
                        var pitch = if(i < 15) { p1 } { p2 };
                        if(c.notNil and: { nd.notNil } and: { c[\diviKnob].notNil } and: { c[\diviKnob].value.notNil } and: { pitch.notNil } and: { pitch > 20 }) {
                            var dv = c[\diviKnob].value.linlin(0, 1, 1, 32).round.asInteger;
                            var ov = c[\oktKnob].value.linlin(0, 1, -3, 3).round.asInteger;
                            var ct = c[\detuneKnob].value.linlin(0, 1, -100, 100).round.asInteger;
                            var freq = pitch / dv * (ct * 0.01).midiratio * 2.pow(ov);
                            nd.string_(hzToNoteCents.(freq));
                        } {
                            if(nd.notNil) { nd.string_("—") };
                        };
                    };
                };
            }.defer;
        }
    }).play(AppClock); // Note-Anzeige auf AppClock (GUI-Interaktion)

    y = y + 55;

    // Presets
    StaticText(p, Rect(20, y, 200, 22)).string_("PRESETS")
        .stringColor_(sc).font_(Font("Helvetica", 11, true));
    y = y + 28;

    presetList = ListView(p, Rect(20, y, 428, 120))
        .background_(Color.gray(0.95))
        .stringColor_(Color.gray(0.15))
        .font_(Font("Helvetica", 13));
    y = y + 128;

    presetNameField = TextField(p, Rect(20, y, 220, 22))
        .background_(Color.gray(0.95))
        .stringColor_(Color.gray(0.15))
        .string_("preset_01");

    Button(p, Rect(248, y, 66, 22))
        .states_([["Speichern", Color.white, Color(0.15, 0.45, 0.15)]])
        .action_({
            var name = presetNameField.string.stripWhiteSpace;
            if(name.size > 0) {
                savePreset.(name);
                refreshPresetList.();
            };
        });

    Button(p, Rect(320, y, 60, 22))
        .states_([["Laden", Color.gray(0.15), Color.gray(0.72)]])
        .action_({
            var sel = presetList.value;
            if(sel.notNil) { loadPreset.(presetList.items[sel]) };
        });

    Button(p, Rect(388, y, 60, 22))
        .states_([["Ordner", Color.gray(0.15), Color.gray(0.72)]])
        .action_({
            var path = ~projPath +/+ "Presets";
            if(thisProcess.platform.name == \windows) {
                "explorer %".format(path).unixCmd
            } {
                "open %".format(path).unixCmd
            };
        });

    y = y + 55;

    // MIDI OUT
    StaticText(p, Rect(20, y, 300, 22)).string_("MIDI OUT")
        .stringColor_(sc).font_(Font("Helvetica", 11, true));
    y = y + 28;

    {
    var dests = MIDIClient.destinations.collect { |d| d.name };
    StaticText(p, Rect(20, y, 80, 22)).string_("Destination:").stringColor_(lc);
    midiDestMenu = PopUpMenu(p, Rect(105, y, 280, 22))
        .items_(if(dests.size > 0) { dests } { ["(keine)"] })
        .action_({ |m|
            if(MIDIClient.destinations.size > 0) {
                ~midiOut = MIDIOut.new(m.value);
                ~midiOut.latency = 0;
            };
        });
    if(dests.size > 0) { ~midiOut = MIDIOut.new(0); ~midiOut.latency = 0 };

    Button(p, Rect(395, y, 55, 22)).states_([["Scan", lc, Color.gray(0.72)]])
    .action_({
        var newDests;
        (~projPath +/+ "MIDIdefs.scd").load;
        newDests = MIDIClient.destinations.collect { |d| d.name };
        midiDestMenu.items_(if(newDests.size > 0) { newDests } { ["(keine)"] });
        if(newDests.size > 0) { ~midiOut = MIDIOut.new(midiDestMenu.value); ~midiOut.latency = 0 };
    });
    }.value;

    StaticText(p, Rect(462, y, 50, 22)).string_("Kanal:").stringColor_(lc);
    PopUpMenu(p, Rect(515, y, 55, 22))
        .items_((1..16).collect(_.asString))
        .action_({ |m| ~midiChan = m.value });
    y = y + 32;

    {
    var ccItems = (0..127).collect(_.asString);
    var ccLabels = ["Pitch 1", "Press 1", "Pitch 2", "Press 2"];
    4.do { |i|
        Button(p, Rect(20, y, 40, 22))
        .states_([
            ["ON",  Color.white, Color(0.15, 0.45, 0.15)],
            ["OFF", Color.gray(0.15), Color.gray(0.75)]
        ])
        .value_(1)
        .action_({ |btn| ~midiCCActive[i] = (btn.value == 0) });
        StaticText(p, Rect(64, y, 60, 22)).string_(ccLabels[i] ++ ":").stringColor_(lc);
        PopUpMenu(p, Rect(125, y, 75, 22))
            .items_(ccItems)
            .value_(~midiCCNums[i])
            .action_({ |m| ~midiCCNums[i] = m.value });
        y = y + 26;
    };
    }.value;

}.value;


//// BAR PANEL //////////////////////////////////////////////////////////////
~manualControls = Array.newClear(30);
~manualRows = Array.newClear(30);
~noteDisps = Array.newClear(30);

~copyMixtur = { |startIdx|
    ~mixturClipboard = 5.collect { |j|
        var c = ~manualControls[startIdx + j];
        (
            wf:   c[\wf].value,
            divi: c[\diviKnob].value.linlin(0,1,1,32).round.asInteger,
            detune: c[\detuneKnob].value.linlin(0,1,-100,100).round.asInteger,
            okt:  c[\oktKnob].value.linlin(0,1,-3,3).round.asInteger,
            amp:  c[\ampKnob].value,
            pan:  c[\panKnob].value.linlin(0,1,-1,1)
        )
    };
    "Mixtur kopiert.".postln;
};

~pasteMixtur = { |startIdx|
    if(~mixturClipboard.notNil) {
        5.do { |j|
            var c = ~manualControls[startIdx + j];
            var d = ~mixturClipboard[j];
            var si = startIdx + j;
            c[\wf].value_(d[\wf]);
            if(~synths.notNil and: { ~synths[si].notNil }) { ~synths[si].set(\waveform, d[\wf]) };
            c[\diviKnob].value_(d[\divi].linlin(1,32,0,1)); c[\diviDisp].string_(d[\divi].asString);
            if(~synths.notNil and: { ~synths[si].notNil }) { ~synths[si].set(\divi, d[\divi]) };
            c[\detuneKnob].value_(d[\detune].linlin(-100,100,0,1)); c[\detuneDisp].string_(d[\detune].asString ++ " ct");
            if(~synths.notNil and: { ~synths[si].notNil }) { ~synths[si].set(\detune, d[\detune]) };
            c[\oktKnob].value_(d[\okt].linlin(-3,3,0,1)); c[\oktDisp].string_(d[\okt].asString);
            if(~synths.notNil and: { ~synths[si].notNil }) { ~synths[si].set(\okt, d[\okt]) };
            c[\ampKnob].value_(d[\amp]);
            if(~synths.notNil and: { ~synths[si].notNil }) { ~synths[si].set(\amp, d[\amp]) };
            c[\panKnob].value_(d[\pan].linlin(-1,1,0,1));
            if(~synths.notNil and: { ~synths[si].notNil }) { ~synths[si].set(\pan, d[\pan]) };
        };
        ~markDirty.(startIdx);
        "Mixtur eingefügt.".postln;
    } {
        "Clipboard leer.".postln;
    };
};




/*
Alle 15 Stimmen eines Manuals verwerfen und aus den aktuellen Werten neu
aufbauen. Frisch erzeugte Oszillatoren starten phasengleich.

Wird ausschliesslich in der Stille aufgerufen (siehe sensorTask). Ein Austausch
im klingenden Ton waere hoerbar.
*/


~markDirty = { |si| ~voicesDirty[if(si < 15) { 0 } { 1 }] = true };

~rebuildVoices = { |manual|
    var offset = manual * 15;
    if(~synths.notNil and: { ~manualControls.notNil }
        and: { ~outBuses.notNil } and: { ~routeSynths.notNil }) {
        s.makeBundle(nil, {
            15.do { |j|
                var i = offset + j;
                var c = ~manualControls[i];
                if(c.notNil and: { c[\diviKnob].notNil }) {
                    ~synths[i] !? { ~synths[i].free };
                    ~synths[i] = Synth(\trauti, [
                        \out,      ~outBuses[i],
                        \pitchBus, ~pitchIdxs[i],
                        \pressBus, ~pressIdxs[i],
                        \waveform, c[\wf].value,
                        \divi,     c[\diviKnob].value.linlin(0, 1, 1, 32).round.asInteger,
                        \okt,      c[\oktKnob].value.linlin(0, 1, -3, 3).round.asInteger,
                        \detune,   c[\detuneKnob].value.linlin(0, 1, -100, 100).round.asInteger,
                        \amp,      c[\ampKnob].value,
                        \pan,      c[\panKnob].value.linlin(0, 1, -1, 1),
                        \lagTime,  klangKnobs[manual] !? { |k| k[\lagPressKnob].value.round(0.01) } ?? 0.2
                    ], ~routeSynths[0], \addBefore);
                };
            };
        });
    };
};

~updateMixturHighlight = { |manual, activeMixtur|
    if(~manualRows.notNil) {
        var offset = (manual - 1) * 15;
        3.do { |m|
            5.do { |j|
                var idx = offset + (m * 5) + j;
                var col = if(m == (activeMixtur - 1)) { Color.gray(0.72) } { Color.gray(0.82) };
                { ~manualRows[idx].notNil.if { ~manualRows[idx].background_(col) } }.defer;
            };
        };
    };
};

makeManualPanel = { |panel, offset|
    var rowH, x;
    rowH = 52;
    x = (nr: 10, wf: 50, divi: 210, diviL: 250,
         detune: 285, detuneL: 323, okt: 397, oktL: 435,
         note: 478, amp: 562, pan: 630);

    [["Waveform", x.wf], ["Divi", x.divi + 10], ["Detune", x.detune + 3],
     ["Okt", x.okt + 10], ["Note", x.note + 8], ["Amp", x.amp + 8], ["Pan", x.pan + 9]].do { |pair|
        StaticText(panel, Rect(pair[1], 4, 90, 20))
        .string_(pair[0]).stringColor_(Color.gray(0.40))
        .font_(Font("Helvetica", 10, true));
    };

    15.do { |i|
        var si, y, wfMenu, diviKnob, diviDisp, detuneKnob, detuneDisp, oktKnob, oktDisp, noteDisp, ampKnob, panKnob;
        si = offset + i;
        y  = 26 + (i * rowH);

        ~manualRows[si] = View(panel, Rect(0, y, 756, rowH))
            .background_(if(i < 5) { Color.gray(0.72) } { Color.gray(0.82) });

        StaticText(panel, Rect(x.nr, y + 16, 45, 20))
        .string_((i + 1).asString).stringColor_(Color.gray(0.15)).align_(\center);

        wfMenu = PopUpMenu(panel, Rect(x.wf, y + 14, 122, 24))
        .items_(["Sine", "Tri", "Square", "Saw", "Blip", "Noise"]).value_(3)
        .action_({ |m|
            if(~synths.notNil and: { ~synths[si].notNil }) { ~synths[si].set(\waveform, m.value) }
        });

        diviDisp = StaticText(panel, Rect(x.diviL, y + 16, 28, 20))
        .string_("8").stringColor_(Color.gray(0.15));
        diviKnob = Knob(panel, Rect(x.divi, y + 9, 36, 36))
        .mode_(\vert).value_(7/31)
        .action_({ |k|
            var dv = k.value.linlin(0, 1, 1, 32).round.asInteger;
            diviDisp.string_(dv.asString);
            if(~synths.notNil and: { ~synths[si].notNil }) { ~synths[si].set(\divi, dv) };
            ~markDirty.(si);
        })
        .mouseDownAction_({ |k, mx, my, mod, btn, clicks|
            if(clicks == 2) {
                k.value_(7/31); diviDisp.string_("8");
                if(~synths.notNil and: { ~synths[si].notNil }) { ~synths[si].set(\divi, 8) };
                ~markDirty.(si);
            };
        });

        detuneDisp = StaticText(panel, Rect(x.detuneL, y + 16, 50, 20))
        .string_("0 ct").stringColor_(Color.gray(0.15));
        detuneKnob = Knob(panel, Rect(x.detune, y + 9, 36, 36))
        .mode_(\vert).value_(0.5)
        .action_({ |k|
            var ct = k.value.linlin(0, 1, -100, 100).round.asInteger;
            detuneDisp.string_(ct.asString ++ " ct");
            if(~synths.notNil and: { ~synths[si].notNil }) { ~synths[si].set(\detune, ct) };
            ~markDirty.(si);
        })
        .mouseDownAction_({ |k, mx, my, mod, btn, clicks|
            if(clicks == 2) {
                k.value_(0.5); detuneDisp.string_("0 ct");
                if(~synths.notNil and: { ~synths[si].notNil }) { ~synths[si].set(\detune, 0) };
                ~markDirty.(si);
            };
        });

        oktDisp = StaticText(panel, Rect(x.oktL, y + 16, 30, 20))
        .string_("0").stringColor_(Color.gray(0.15));
        oktKnob = Knob(panel, Rect(x.okt, y + 9, 36, 36))
        .mode_(\vert).value_(0.5)
        .action_({ |k|
            var ov = k.value.linlin(0, 1, -3, 3).round.asInteger;
            oktDisp.string_(ov.asString);
            if(~synths.notNil and: { ~synths[si].notNil }) { ~synths[si].set(\okt, ov) };
            ~markDirty.(si);
        })
        .mouseDownAction_({ |k, mx, my, mod, btn, clicks|
            if(clicks == 2) {
                k.value_(0.5); oktDisp.string_("0");
                if(~synths.notNil and: { ~synths[si].notNil }) { ~synths[si].set(\okt, 0) };
                ~markDirty.(si);
            };
        });

        noteDisp = StaticText(panel, Rect(x.note, y + 16, 80, 20))
        .string_("—").stringColor_(Color.gray(0.45)).font_(Font("Helvetica", 10));
        ~noteDisps[si] = noteDisp;

        ampKnob = Knob(panel, Rect(x.amp, y + 9, 36, 36))
        .mode_(\vert).value_(0)
        .action_({ |k|
            if(~synths.notNil and: { ~synths[si].notNil }) { ~synths[si].set(\amp, k.value) }
        })
        .mouseDownAction_({ |k, mx, my, mod, btn, clicks|
            if(clicks == 2) {
                k.value_(0);
                if(~synths.notNil and: { ~synths[si].notNil }) { ~synths[si].set(\amp, 0) };
            };
        });

        panKnob = Knob(panel, Rect(x.pan, y + 9, 36, 36))
        .mode_(\vert).value_(0.5)
        .action_({ |k|
            if(~synths.notNil and: { ~synths[si].notNil }) { ~synths[si].set(\pan, k.value.linlin(0, 1, -1, 1)) }
        })
        .mouseDownAction_({ |k, mx, my, mod, btn, clicks|
            if(clicks == 2) {
                k.value_(0.5);
                if(~synths.notNil and: { ~synths[si].notNil }) { ~synths[si].set(\pan, 0) };
            };
        });

        if(i % 5 == 2) {
            var mxtStart = si - 2;
            Button(panel, Rect(682, y + 6, 30, 22))
            .states_([["C", Color.gray(0.15), Color.gray(0.72)]])
            .action_({ ~copyMixtur.(mxtStart) });
            Button(panel, Rect(716, y + 6, 30, 22))
            .states_([["P", Color.gray(0.15), Color.gray(0.72)]])
            .action_({ ~pasteMixtur.(mxtStart) });
        };

        ~manualControls[si] = (
            wf:       wfMenu,
            diviKnob: diviKnob, diviDisp: diviDisp,
            detuneKnob: detuneKnob, detuneDisp: detuneDisp,
            oktKnob:  oktKnob,  oktDisp:  oktDisp,
            ampKnob:  ampKnob,
            panKnob:  panKnob
        );
    };
};

makeManualPanel.(panels[1], 0);   // Mixturen 1: Synths 1-15
makeManualPanel.(panels[3], 15);  // Mixturen 2: Synths 16-30


//// KLANG PANEL (Helper) //////////////////////////////////////////////////////////////
klangKnobs   = Array.newClear(2);
~levelMeters = Array.newClear(2);

// SendPeakRMS im \masterToOut schickt 15-mal je Sekunde Spitze und Effektivwert
// beider Kanaele. Aufbau der Nachricht:
//   [cmdName, nodeID, replyID, peakL, rmsL, peakR, rmsR]
// replyID ist unser meterIdx und unterscheidet die beiden Manuale.
OSCdef(\masterLevel, { |msg|
    var idx = msg[2].asInteger;
    {
        var pair = ~levelMeters !? { ~levelMeters[idx] };
        if(pair.notNil) {
            2.do { |ch|
                var m = pair[ch];
                if(m.notNil and: { m.isClosed.not }) {
                    m.value_(     msg[4 + (ch * 2)].ampdb.linlin(-60, 12, 0, 1));
                    m.peakLevel_( msg[3 + (ch * 2)].ampdb.linlin(-60, 12, 0, 1));
                };
            };
        };
    }.defer;
}, '/masterLevel');
{
    var makeKlangPanel;

    makeKlangPanel = { |panel, routeIdx|
        var p, y, lc, sc, bc;
        var makeKnob;
        var manualIdx, freqKnobs, decayKnobs, levelKnobs, dryWetKnob, verbKnob, lpKnob, lpModKnob, svfResoKnob, lagPressKnob, lagMixKnob, mainvolKnob;
        p  = panel;
        y  = 30;
        lc = Color.gray(0.15);
        sc = Color.gray(0.35);
        bc = Color.gray(0.72);

        makeKnob = { |parent, px, py, default, label, action, resetAction|
            var knob, disp;
            knob = Knob(parent, Rect(px, py, 44, 44))
                .mode_(\vert).value_(default)
                .action_(action)
                .mouseDownAction_({ |k, mx, my, mod, btn, clicks|
                    if(clicks == 2) { resetAction.(k) };
                });
            disp = StaticText(parent, Rect(px - 8, py + 48, 60, 18))
                .stringColor_(lc).font_(Font("Helvetica", 10)).align_(\center);
            StaticText(parent, Rect(px - 8, py + 64, 60, 16))
                .string_(label).stringColor_(sc).font_(Font("Helvetica", 9)).align_(\center);
            [knob, disp]
        };

        //// Formant Filter //////////////////////////////////////////////////////////////
        StaticText(p, Rect(20, y, 300, 22)).string_("FORMANT FILTER")
            .stringColor_(sc).font_(Font("Helvetica", 11, true));
        y = y + 30;

        // Band headers
        ["Band 1", "Band 2", "Band 3"].do { |label, bi|
            StaticText(p, Rect(20 + (bi * 220), y, 200, 18))
                .string_(label).stringColor_(Color.gray(0.45))
                .font_(Font("Helvetica", 10, true));
        };
        y = y + 22;

        // 3 bands × 3 params (Freq, Reso, Level)
        manualIdx = routeIdx - 6;
        freqKnobs  = Array.newClear(3);
        decayKnobs  = Array.newClear(3);
        levelKnobs = Array.newClear(3);

        3.do { |bi|
            var bx = 20 + (bi * 220);
            var freqDefault = [320, 1000, 3200][bi];
            var freqArg  = [\freq1,  \freq2,  \freq3 ][bi];
            var decayArg  = [\decay1,  \decay2,  \decay3 ][bi];
            var levelArg = [\level1, \level2, \level3][bi];
            var levelDefault = [0.5, 0, 0][bi];
            var decayDefault = 1/1100;   // entspricht Knopfstellung 1.0

            // Freq — stufenlos 200 bis 5000 Hz, exponentiell verteilt.
            // 1000 Hz liegt dadurch genau in der Reglermitte, weil es das
            // geometrische Mittel der beiden Grenzen ist.
            {
                var knob, disp;
                var knobDefault = freqDefault.explin(200, 5000, 0, 1);
                var show = { |f| f.round.asInteger.asString ++ " Hz" };
                knob = Knob(p, Rect(bx, y, 44, 44))
                    .mode_(\vert).value_(knobDefault)
                    .action_({ |k|
                        var freq = k.value.linexp(0, 1, 200, 5000);
                        disp.string_(show.(freq));
                        if(~routeSynths.notNil) { ~routeSynths[routeIdx].set(freqArg, freq) };
                    })
                    .mouseDownAction_({ |k, mx, my, mod, btn, clicks|
                        if(clicks == 2) {
                            k.value_(knobDefault);
                            disp.string_(show.(freqDefault));
                            if(~routeSynths.notNil) { ~routeSynths[routeIdx].set(freqArg, freqDefault) };
                        };
                    });
                disp = StaticText(p, Rect(bx - 20, y + 48, 90, 18))
                    .string_(show.(freqDefault))
                    .stringColor_(Color.gray(0.15)).font_(Font("Helvetica", 10)).align_(\center);
                StaticText(p, Rect(bx - 8, y + 64, 60, 16))
                    .string_("Freq").stringColor_(Color.gray(0.35))
                    .font_(Font("Helvetica", 9)).align_(\center);
                freqKnobs[bi] = knob;
            }.value;

            // Abklingzeit von Ringz. Kurz = breites Band, lang = schmal und
            // klingend — die Reglerrichtung bleibt damit "aufdrehen = breiter".
            decayKnobs[bi] = makeKnob.(p, bx + 70, y,
                1.0, "Breite",
                { |k|
                    var dec = k.value.linexp(0.001, 1, 1/60, 1/1100); //60Hz bis 1100Hz Breite
                    if(~routeSynths.notNil) { ~routeSynths[routeIdx].set(decayArg, dec) };
                },
                { |k|
                    k.value_(1.0);
                    if(~routeSynths.notNil) { ~routeSynths[routeIdx].set(decayArg, decayDefault) };
                }
            )[0];

            // Level — Band 1 steht auf 12 Uhr, Band 2 und 3 auf null.
            levelKnobs[bi] = makeKnob.(p, bx + 140, y,
                levelDefault, "Level",
                { |k|
                    if(~routeSynths.notNil) { ~routeSynths[routeIdx].set(levelArg, k.value.linlin(0, 1, 0, 4)) };
                },
                { |k|
                    k.value_(levelDefault);
                    if(~routeSynths.notNil) {
                        ~routeSynths[routeIdx].set(levelArg, levelDefault.linlin(0, 1, 0, 4))
                    };
                }
            )[0];
        };

        y = y + 100;

        //// Dry/Wet //////////////////////////////////////////////////////////////
        StaticText(p, Rect(20, y, 300, 22)).string_("FILTER MIX")
            .stringColor_(sc).font_(Font("Helvetica", 11, true));
        y = y + 30;

        dryWetKnob = makeKnob.(p, 20, y,
            0, "Dry/Wet",
            { |k| if(~routeSynths.notNil) { ~routeSynths[routeIdx].set(\dryWet, k.value) } },
            { |k| k.value_(0); if(~routeSynths.notNil) { ~routeSynths[routeIdx].set(\dryWet, 0) } }
        )[0];

        y = y + 100;

        //// SVF //////////////////////////////////////////////////////////////
        StaticText(p, Rect(20, y, 300, 22)).string_("SVF")
            .stringColor_(sc).font_(Font("Helvetica", 11, true));
        y = y + 30;

        {
            var pair = makeKnob.(p, 20, y,
                4000.explin(20, 20000, 0.001, 1), "Cutoff",
                { |k|
                    var freq = k.value.linexp(0.001, 1, 20, 20000);
                    pair[1].string_(freq.round(1).asInteger.asString ++ " Hz");
                    if(~routeSynths.notNil) { ~routeSynths[routeIdx].set(\lpFreq, freq) };
                },
                { |k|
                    k.value_(4000.explin(20, 20000, 0.001, 1));
                    pair[1].string_("4000 Hz");
                    if(~routeSynths.notNil) { ~routeSynths[routeIdx].set(\lpFreq, 4000) };
                }
            );
            pair[1].string_("4000 Hz");
            lpKnob = pair[0];
        }.value;

        {
        lpModKnob = makeKnob.(p, 90, y,
            0, "press mod",
            { |k|
                var amt = k.value;
                if(~routeSynths.notNil) { ~routeSynths[routeIdx].set(\lpMod, amt) };
            },
            { |k|
                k.value_(0);
                if(~routeSynths.notNil) { ~routeSynths[routeIdx].set(\lpMod, 0) };
            }
        )[0];
        }.value;

        svfResoKnob = makeKnob.(p, 160, y,
            0, "Resonanz",
            { |k|
                if(~routeSynths.notNil) { ~routeSynths[routeIdx].set(\svfReso, k.value) };
            },
            { |k|
                k.value_(0);
                if(~routeSynths.notNil) { ~routeSynths[routeIdx].set(\svfReso, 0) };
            }
        )[0];

        y = y + 100;

        //// Reverb //////////////////////////////////////////////////////////////
        StaticText(p, Rect(20, y, 300, 22)).string_("REVERB")
            .stringColor_(sc).font_(Font("Helvetica", 11, true));
        y = y + 30;

        verbKnob = makeKnob.(p, 20, y,
            0, "Reverb",
            { |k| if(~routeSynths.notNil) { ~routeSynths[routeIdx].set(\verbvol, k.value) } },
            { |k| k.value_(0); if(~routeSynths.notNil) { ~routeSynths[routeIdx].set(\verbvol, 0) } }
        )[0];

        y = y + 100;

        //// Lag //////////////////////////////////////////////////////////////
        StaticText(p, Rect(20, y, 300, 22)).string_("LAG")
            .stringColor_(sc).font_(Font("Helvetica", 11, true));
        y = y + 30;

        {
            var pair = makeKnob.(p, 20, y,
                0.2, "Lag Press",
                { |k|
                    var val = k.value.round(0.01);
                    var range = if(manualIdx == 0) { (0..14) } { (15..29) };
                    pair[1].string_(val.asString);
                    if(~synths.notNil) { range.do { |i| ~synths[i].notNil.if { ~synths[i].set(\lagTime, val) } } };
                },
                { |k|
                    var range = if(manualIdx == 0) { (0..14) } { (15..29) };
                    k.value_(0.2);
                    pair[1].string_("0.2");
                    if(~synths.notNil) { range.do { |i| ~synths[i].notNil.if { ~synths[i].set(\lagTime, 0.2) } } };
                }
            );
            pair[1].string_("0.2");
            lagPressKnob = pair[0];
        }.value;

        {
            var pair = makeKnob.(p, 90, y,
                0.1, "Lag Mixtur",
                { |k|
                    var val = k.value.round(0.01);
                    var range = if(manualIdx == 0) { (0..2) } { (3..5) };
                    pair[1].string_(val.asString);
                    if(~routeSynths.notNil) { range.do { |i| ~routeSynths[i].set(\lagTime, val) } };
                },
                { |k|
                    var range = if(manualIdx == 0) { (0..2) } { (3..5) };
                    k.value_(0.1);
                    pair[1].string_("0.1");
                    if(~routeSynths.notNil) { range.do { |i| ~routeSynths[i].set(\lagTime, 0.1) } };
                }
            );
            pair[1].string_("0.1");
            lagMixKnob = pair[0];
        }.value;

        {
            var pair = makeKnob.(p, 670, panelH - 105,
                0.5, "mainvol",
                { |k|
                    var val = k.value.linlin(0, 1, 0, 2).round(0.01);
                    pair[1].string_(val.asString);
                    if(~routeSynths.notNil) { ~routeSynths[routeIdx].set(\mainvol, val) };
                },
                { |k|
                    k.value_(0.5);
                    pair[1].string_("1.0");
                    if(~routeSynths.notNil) { ~routeSynths[routeIdx].set(\mainvol, 1.0) };
                }
            );
            pair[1].string_("1.0");
            mainvolKnob = pair[0];
        }.value;

        // Pegelanzeige des Manuals, gemessen vor dem Limiter.
        // Skala -60 bis +12 dB; 0 dB liegt bei 0.833 der Anzeigehoehe. Ab dort
        // faengt der Limiter an zu arbeiten — Rot heisst also nicht "uebersteuert",
        // sondern "der Limiter greift ein".
        {
            var mh = 340;                      // Hoehe der Anzeige
            var mx = 681, my = panelH - 105 - mh - 12;
            // Zwei Balken nebeneinander — links und rechts
            ~levelMeters[manualIdx] = 2.collect { |ch|
                LevelIndicator(p, Rect(mx + (ch * 17), my, 15, mh))
                    .warning_(0.75)     // -6 dB
                    .critical_(0.833)   //  0 dB
                    .drawsPeak_(true)
                    .numTicks_(13).numMajorTicks_(7)
                    .background_(Color.gray(0.95))
                    .meterColor_(Color(0.15, 0.45, 0.15))
                    .warningColor_(Color(0.75, 0.45, 0))
                    .criticalColor_(Color(0.7, 0.1, 0.1));
            };
        }.value;

        klangKnobs[manualIdx] = (
            freqKnobs:    freqKnobs,
            decayKnobs:    decayKnobs,
            levelKnobs:   levelKnobs,
            dryWetKnob:   dryWetKnob,
            verbKnob:     verbKnob,
            lpKnob:       lpKnob,
            lpModKnob:    lpModKnob,
            svfResoKnob:  svfResoKnob,
            lagPressKnob: lagPressKnob,
            lagMixKnob:   lagMixKnob,
            mainvolKnob:  mainvolKnob
        );

    };

    makeKlangPanel.(panels[2], 6);  // Klang 1 → routeSynths[6] = masterToOut Manual 1
    makeKlangPanel.(panels[4], 7);  // Klang 2 → routeSynths[7] = masterToOut Manual 2

}.value;


//// PRESET FUNCTIONS //////////////////////////////////////////////////////////////
{
    var presetsPath;
    presetsPath = ~projPath +/+ "Presets";

    savePreset = { |name|
        var data = ();
        data[\waveforms] = ~manualControls.collect { |c| c[\wf].value };
        data[\divis]     = ~manualControls.collect { |c| c[\diviKnob].value.linlin(0,1,1,32).round.asInteger };
        data[\detunes]     = ~manualControls.collect { |c| c[\detuneKnob].value.linlin(0,1,-100,100).round.asInteger };
        data[\okts]      = ~manualControls.collect { |c| c[\oktKnob].value.linlin(0,1,-3,3).round.asInteger };
        data[\amps]      = ~manualControls.collect { |c| c[\ampKnob].value };
        data[\pans]      = ~manualControls.collect { |c| c[\panKnob].value.linlin(0,1,-1,1) };
        data[\klang] = 2.collect { |bi|
            var k = klangKnobs[bi];
            (
                freqs:    k[\freqKnobs].collect  { |kn| kn.value },
                decays:   k[\decayKnobs].collect  { |kn| kn.value },
                levels:   k[\levelKnobs].collect { |kn| kn.value },
                dryWet:   k[\dryWetKnob].value,
                verbvol:  k[\verbKnob].value,
                lpFreq:   k[\lpKnob].value.linexp(0.001, 1, 20, 20000).round(1),
                lpMod:    k[\lpModKnob].value,
                svfReso:  k[\svfResoKnob].value,
                lagPress: k[\lagPressKnob].value,
                lagMix:   k[\lagMixKnob].value,
                mainvol:  k[\mainvolKnob].value.linlin(0, 1, 0, 2)
            )
        };
        {
            var f = File(presetsPath +/+ name ++ ".scd", "w");
            f.write(data.asCompileString);
            f.close;
        }.value;
        "Preset gespeichert: %".format(name).postln;
    };

    loadPreset = { |name|
        var data, path;
        path = presetsPath +/+ name ++ ".scd";
        data = path.load;
        if(data.notNil) {
            30.do { |i|
                var c = ~manualControls[i];
                var dv, ov, freq, av, pv;
                c[\wf].value_(data[\waveforms][i]);
                if(~synths.notNil and: { ~synths[i].notNil }) { ~synths[i].set(\waveform, data[\waveforms][i]) };
                dv = data[\divis][i];
                c[\diviKnob].value_(dv.linlin(1,32,0,1));
                c[\diviDisp].string_(dv.asString);
                if(~synths.notNil and: { ~synths[i].notNil }) { ~synths[i].set(\divi, dv) };
                { |tv|
                    tv = data[\detunes][i];
                    c[\detuneKnob].value_(tv.linlin(-100,100,0,1));
                    c[\detuneDisp].string_(tv.asString ++ " ct");
                    if(~synths.notNil and: { ~synths[i].notNil }) { ~synths[i].set(\detune, tv) };
                }.value;
                ov = data[\okts][i];
                c[\oktKnob].value_(ov.linlin(-3,3,0,1));
                c[\oktDisp].string_(ov.asString);
                if(~synths.notNil and: { ~synths[i].notNil }) { ~synths[i].set(\okt, ov) };
                av = data[\amps][i];
                c[\ampKnob].value_(av);
                if(~synths.notNil and: { ~synths[i].notNil }) { ~synths[i].set(\amp, av) };
                pv = data[\pans][i];
                c[\panKnob].value_(pv.linlin(-1,1,0,1));
                if(~synths.notNil and: { ~synths[i].notNil }) { ~synths[i].set(\pan, pv) };
            };
            // Klang
            if(data[\klang].notNil) {
                2.do { |bi|
                    var kd = data[\klang][bi];
                    var kk = klangKnobs[bi];
                    3.do { |fi|
                        // valueAction_ statt value_: loest die Knopfaktion aus und
                        // laesst diese den Synth setzen und die Zahl darunter
                        // schreiben. value_ allein verschoebe nur den Zeiger, die
                        // Anzeige bliebe auf dem alten Wert stehen.
                        // Zugleich gibt es damit nur noch eine Stelle, an der die
                        // Umrechnung steht. Die frueher hier wiederholten Formeln
                        // waren bereits aus dem Tritt geraten.
                        var fv = kd[\freqs][fi];
                        var rv = kd[\decays][fi];
                        var lv = kd[\levels][fi];
                        kk[\freqKnobs][fi].valueAction_(fv);
                        kk[\decayKnobs][fi].valueAction_(rv);
                        kk[\levelKnobs][fi].valueAction_(lv);
                    };
                    kk[\dryWetKnob].valueAction_(kd[\dryWet]);
                    kk[\verbKnob].valueAction_(kd[\verbvol]);
                    kd[\lpFreq]  !? { |v| kk[\lpKnob].valueAction_(v.explin(20, 20000, 0.001, 1)) };
                    kd[\lpMod]   !? { |v| kk[\lpModKnob].valueAction_(v) };
                    kd[\svfReso] !? { |v| kk[\svfResoKnob].valueAction_(v) };
                    kd[\lagPress] !? { |v| kk[\lagPressKnob].valueAction_(v) };
                    kd[\lagMix]   !? { |v| kk[\lagMixKnob].valueAction_(v) };
                    kd[\mainvol]  !? { |v| kk[\mainvolKnob].valueAction_(v.linlin(0, 2, 0, 1)) };
                };
            };
            ~markDirty.(0);
            ~markDirty.(15);
            "Preset geladen: %".format(name).postln;
        } {
            "Preset nicht gefunden: %".format(name).postln;
        };
    };

    refreshPresetList = {
        var files = (presetsPath +/+ "*.scd").pathMatch
            .collect { |p| p.basename.splitext[0] }
            .sort;
        presetList.items_(files);
        if(presetNameField.notNil) {
            var n = files.size + 1;
            presetNameField.string_("preset_" ++ n.asString.padLeft(2, "0"));
        };
    };
}.value;

{ refreshPresetList.() }.defer(0.5);



win.onClose_({
    sensorTask.stop;
    ~midiTask.stop;
    OSCdef(\masterLevel).free;
    ~levelMeters = nil;
    ~synths.do      { |syn| syn.free };
    ~routeSynths.do { |syn| syn.free };
    ~stopSerial.();
});

win.front;
"GUI geladen.".postln;
)
