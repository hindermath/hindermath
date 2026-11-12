# Barrierefreiheit des Profils / Profile accessibility

Stand / Date: 2026-11-12. Owner: Thorsten Hindermann.

`Programmierung #include<everyone>` ist die Leitlinie. Die Profil-README wird
gegen anwendbare WCAG-2.2-AA-Kriterien geprüft. Dieser Nachweis unterscheidet
umgesetzte Verbesserungen, technische Prüfungen und praktische Testgrenzen.
Er ist keine pauschale Konformitätserklärung für die gesamte GitHub-Oberfläche.

*The profile is assessed against applicable WCAG 2.2 AA criteria. This record
distinguishes implemented improvements, technical verification and practical
test limits. It does not declare the whole GitHub interface conformant.*

## Umsetzung / Implementation

- Deutsch ist innerhalb der README die ausdrücklich markierte Hauptsprache.
  Englische Absätze, Listenübersetzungen und Überschriftenteile tragen `lang="en"`.
  Der MOTD-Generator erhält beide Sprachen und escaped Nachrichtentext.
- Die Berufszeile und der Leitspruch sind hervorgehobener Text. Ein Haupttitel,
  Hauptabschnitte auf Ebene 2 und Projekt-/Technologiegruppen auf Ebene 3
  strukturieren die README.
- 36 Technologie-Badges behalten ihre Identität mit weißen Beschriftungen auf
  `#334155`; der Grundfarbenkontrast beträgt ungefähr 10,35:1. Verbleibende
  Bildtexte benennen das tatsächliche Produkt. 26 redundante Projekt-/Kontakt-
  Badges wurden durch echten Text ersetzt; Inventarisierung ist ausdrücklich
  benannt. Text lässt sich unabhängig von Bildern anpassen.
- Die 15 Inhaltsverzeichnislinks verwenden ausdrücklich benannte, stabile
  ASCII-Ziele. Die Links enthalten GitHubs tatsächlich erzeugtes Präfix
  `user-content-`; sie hängen nicht mehr von Herzsymbolen oder Übersetzung ab.
- Der kompatible Statistikimport akzeptiert bisherige Exporte und
  `accessible-html-v1`. Namen, Sprache, Spalten- und Zeilenüberschriften werden
  vor Import validiert; DTDs, Skripte, Eventattribute und fremde Linkziele sind
  nicht erlaubt. Der Tabellenblock bleibt bytegleich zur zentralen deutschen
  Quelle. Zählungen und Belegstände werden für diese Darstellung nicht verändert.

*Explicit German/English boundaries, a coherent heading hierarchy, high-contrast
technology badges, real project metadata, fifteen stable navigation targets and
strictly validated semantic statistics address the recorded findings. Daily
MOTD and monthly import preserve the improvements. The imported German block
remains identical to Level 0 without changing numeric evidence or source dates.*

## Reproduzierbare Prüfungen / Reproducible checks

```powershell
pwsh -NoProfile -File .github/scripts/test-spec-kit-table.ps1
pwsh -NoProfile -File .github/scripts/test-profile-accessibility.ps1
pwsh -NoProfile -File .github/scripts/update-spec-kit-table.ps1 -CheckOnly
pwsh -NoProfile -File .github/scripts/update-motd.ps1 -WhatIf
```

Die Offline-Tests prüfen Sprachgrenzen, eindeutige Ziele, Badge-Verträge,
MOTD-Escaping/-Determinismus, Vorschau ohne Schreiben, Header, sichere HTML-
Verarbeitung, historische Exporte, Prüfsummen und Erhalt der übrigen README.
CI führt beide Tests bei README-, Skript- und MOTD-Workflow-Änderungen aus.

*Offline tests cover language/navigation/badge contracts, deterministic and
escaped messages, no-write preview, safe semantic import, historical exports,
checksums and preservation. CI reruns both suites for the relevant changes.*

## Praktische Prüfung und Grenzen / Practical verification and limits

Der Audit vom 11.11.2026 prüfte im Browser Tastaturfokus, Skip-Link,
Tabellenscrollen und Umbruch bei 320 CSS-Pixeln. Er belegte auch die zu
korrigierenden Sprach-/Kontrastprobleme und das unzuverlässige Anspringen
automatisch abgeleiteter Überschriftenfragmente. Diese historische Prüfung
ist kein Nachweis des neuen Stands. Die Auslieferung wird zusätzlich am
GitHub-gerenderten Kandidaten und auf der veröffentlichten Profilseite geprüft.

*The November 11 audit inspected keyboard focus, skip navigation, scrolling and
320 CSS-pixel reflow, and identified the original problems. That historical
audit is not proof of the new version. Delivery also verifies GitHub-rendered
candidate content and the published profile.*

Am 12.11.2026 wurde der GitHub-gerenderte Kandidat praktisch geprüft:
DE/EN-Sprachgrenzen sind im DOM erhalten, alle 15 Ziele werden bei Enter als
tatsächliche Zielüberschriften erkannt, die Fokusfortsetzung ist sichtbar und
36 statt 62 Badge-Bilder bleiben. In Safari funktionierte der Kontakt-Sprung;
der explizit auf 200 % gesetzte Website-Zoom zeigte vergrößerten, umbrechenden
Text. Die ursprünglichen 100 % wurden anschließend in den Website-Einstellungen
bestätigt. Das ist ein begrenzter Browsernachweis, keine vollständige
200-%-Prüfung aller GitHub-Funktionen.

*The November 12 GitHub-rendered candidate retains language boundaries and all
fifteen targets become actual target headings after Enter; keyboard focus is
visible. Safari independently reached Contact and showed enlarged wrapping text
with website zoom explicitly set to 200%; the original 100% setting was restored
and checked. This is bounded browser evidence, not a full GitHub zoom assessment.*

Der initiale Zugriff auf VoiceOver endete im Timeout. Thorsten meldete danach
ausdrücklich laufendes VoiceOver; es wird nicht durch den Agenten abgeschaltet.
Auf die gezielte Frage nach verständlichen Überschriften/Linknamen und passenden
Sprachwechseln antwortete Thorsten: „Ja, werden mir sehr gut über VoiceOver
vorgelesen.“ Diese menschlich bestätigte Ausgabe ist ein begrenzter praktischer
Teilnachweis. Nicht beobachtete Rotorfunktionen oder eine vollständige
Screenreader-Abnahme werden daraus nicht abgeleitet. Der bereitgestellte Browser bot unter Appearance nur die
Kontrastoption; ein vollständiger Dark-Mode-Test und frei angepasste
Textabstände sind damit noch nicht praktisch belegt.

*The initial VoiceOver access timed out. Thorsten subsequently reported VoiceOver
running; the agent leaves it enabled. Thorsten positively confirmed readable
VoiceOver output in response to the targeted heading/link/language question.
That bounded human observation does not establish unobserved rotor behavior or
full screen-reader acceptance. The supplied appearance dialog exposed only a contrast option;
full dark-mode and custom text-spacing tests remain unproven.*

Nicht als bestanden gewertet: vollständige VoiceOver-/NVDA- und Braille-
Nutzung, nicht tatsächlich ausgeführte Browser-/Zoom-/Textabstandsprüfungen,
sowie alle GitHub-eigenen Dialoge, Anmelde- und Bearbeitungsabläufe. Praktische
Tests werden nur mit beobachtetem Ergebnis berichtet. Braillehardware ist
hier nicht verfügbar. Owner für weitere Prüfungen ist Thorsten; Wiedervorlage
bei Layout-/Renderer-/GitHub-Änderung und vor einer vollständigen
Konformitätserklärung. Fremde GWDG-/LinkedIn-Seiten gehören nicht zum
README-Prüfumfang. Links öffnen nach Browserentscheidung; GitHub entfernt
`target="_blank"` aus README-HTML.

*Do not mark unperformed screen-reader, Braille, browser, zoom or spacing tests
as passed. GitHub-owned flows and linked external sites are separate. Thorsten
owns remaining practical verification; reassess after layout/renderer/GitHub
changes and before a full conformance statement. GitHub strips target=_blank.*

## Dokumentationsauswirkung / Documentation impact

`UpdateRequired`; Owner Thorsten. Kanonisch sind README, MOTD-Generator und
Importskript; Leserpfad Profil → Inhaltsverzeichnis → Projekte/Kontakt und
Statistik → zentrale Methodik. DE/EN stehen gemeinsam in dieser Datei;
Dokumentklasse Wartungs-/Prüfnachweis, Distribution Profilquelle, kein Home-Sync
für dieses Repository. Die Statistikquelle pflegt ihren eigenen Sync-Nachweis.
Re-Evaluation bei geänderten Inhalten, Generatoren oder GitHub-Sanitization.

*UpdateRequired, owned by Thorsten. Canonical README/generators and navigation
retain their reader paths. This bilingual maintenance record belongs to the
profile source; it needs no Home sync. Level 0 has its own distribution contract.*
