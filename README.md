# Traumtonium

Digitales Mixturtrautonium. Zwei Spielmanuale erfassen Position und Druck der
Finger, ein Teensy 4.0 überträgt die Werte seriell. In SuperCollider passiert die Klangerzeugung, 
die den Konzepten des Mixturtrautoniums nach Oskar Sala nachempfunden ist. 

Entstanden als Bachelorarbeit im Studiengang Ton und Bild an der Hochschule
Düsseldorf, Fachbereich Medien, 2026.


## Voraussetzungen

- SuperCollider 3.14.1
- [sc3-plugins](https://github.com/supercollider/sc3-plugins) für die UGens
  `DPW3Tri`, `PulseDPW`, `DPW4Saw`, `SVF` und `JPverb`
- Teensy 4.0 mit der Firmware aus `Teensy4.0_firmware/`
- Traumtonium mit zwei Spielmanualen

## Starten

Cursor in den Klammerblock am Anfang von `main.scd` setzen und mit
`Cmd+Enter` ausführen. Der Block setzt die Puffergröße auf 64 Samples und lädt
die übrigen Dateien. Server und serielle Verbindung werden anschließend über
die Oberfläche gestartet.

## Aufbau

| Datei | Aufgabe |
|---|---|
| `main.scd` | Einstiegspunkt |
| `serial.scd` | Sensordaten empfangen und abbilden |
| `SynthDefs.scd` | die drei Syntheseeinheiten |
| `MIDIdefs.scd` | MIDI-Ein- und -Ausgang |
| `gui.scd` | Oberfläche, Presets, Serverstart |
| `Presets/` | gespeicherte Registrierungen |

`audio_settings.scd` entsteht zur Laufzeit und speichert das vom Benutzer / der Benutzerin ausgewählte Audiogerät und
dessen Kanalzahl und erinniert sich beim nächsten Programmstart daran. Die Datei ist bewusst nicht Teil des
Repositoriums.
