(

// Generatorfrequenzen C6–C8. Die Stimmen entstehen daraus durch
// subharmonische Teilung (freq = pitch / divi), bei divi = 8 klingt C3–C5.
~freqs = [1046.50, 1108.73, 1174.66, 1244.51, 1318.51, 1396.91, 1479.98, 1567.98, 1661.22, 1760.00, 1864.66, 1975.53, 2093.00, 2217.46, 2349.32, 2489.02, 2637.02, 2793.83, 2959.96, 3135.96, 3322.44, 3520.00, 3729.31, 3951.07, 4186.01];

~marks = [0, 100, 207, 311, 423, 524, 635, 733, 840, 941, 1046, 1142, 1246, 1350, 1450,1550, 1650, 1745, 1840, 1945, 2045, 2135, 2235, 2338, 2400];
//~marks = [0, 25, 51, 77, 105, 131, 158, 183, 210, 235, 261, 285, 311, 337, 362, 387, 412, 436, 460, 486, 511, 534, 559, 584, 600];

~mapPitch = { |val|
    var i, lo, hi;
    val = val.clip(~marks.first, ~marks.last);
    i = 0;
    while({ (i < (~marks.size - 2)) and: { val > ~marks[i+1] } }, { i = i + 1 });
    lo = ~marks[i];
    hi = ~marks[i+1];
    val.linexp(lo, hi, ~freqs[i], ~freqs[i+1]);
};

~startSerial = { |portName = "/dev/cu.usbmodem153727001"|
    var chars, counter, ok, devices;
    chars = [];
    counter = 0;
    ok = false;
    devices = SerialPort.devices;

    if(devices.any { |d| d == portName }.not) {
        ("Traumtonium nicht angeschlossen — " ++ portName).postln;
        if(devices.size > 0) {
            "Verfügbare Ports:".postln;
            devices.do { |d| ("   " ++ d).postln };
        } {
            "Es ist kein serielles Gerät angeschlossen.".postln;
        };
        ~port = nil;
    } {
        try {
            ~port = SerialPort.new(portName, 115200, crtscts: true, exclusive: true);
            ok = true;
        } { |err|
            ("FEHLER: Port konnte nicht geöffnet werden — " ++ err.errorString).postln;
            "Läuft noch eine andere Verbindung? Ggf. ~stopSerial.() aufrufen.".postln;
            ~port = nil;
        };
    };

    if(ok) {
    ~lastReceived = Main.elapsedTime;
    ~write = Routine({
        loop {
            var byte, str, values, pitch1, press1, pitch2, press2;
            while({ (byte = ~port.next).notNil }, {
                ~lastReceived = Main.elapsedTime;
                if(byte == 10) {
                    str = chars.join;
                    values = str.split($,);
                    if(values.size >= 4) {
                        pitch1 = values[0].asFloat;
                        press1 = values[1].asFloat;
                        pitch2 = values[2].asFloat;
                        press2 = values[3].asFloat;
                        ~pitch1.set(~mapPitch.(pitch1));
                        ~press1.set(press1.lincurve(8, 500, 0, 1, curve: -2));
                        ~pitch2.set(~mapPitch.(pitch2));
                        ~press2.set(press2.lincurve(8, 500, 0, 1, curve: -2));
                        counter = counter + 1;
                        if(counter >= 40) {
                            if(~serialPost == true) {
                                ("p1:" ++ pitch1 ++ " pr1:" ++ press1 ++
                                 "  p2:" ++ pitch2 ++ " pr2:" ++ press2 ++
                                 "  rxErr:" ++ ~port.rxErrors).postln;
                            };
                            counter = 0;
                        };
                    };
                    chars = [];
                } {
                    if(byte != 13) { chars = chars.add(byte.asAscii) };
                };
            });
            0.005.wait; //5ms wie im teensy
        }
    }).play(SystemClock);
    ("Serial verbunden: " ++ portName).postln;
    };

    ok
};

~stopSerial = {
    if(~write.notNil) { ~write.stop; ~write = nil };
    SerialPort.closeAll;
    ~port = nil;
};

"serial.scd geladen.".postln;
)
