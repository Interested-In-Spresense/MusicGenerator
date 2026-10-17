/*
 * File: AutoMelody.pde
 * Description: Selects source motifs, transforms notes, and writes MIDI arrangements.
 * Author: Intersted_in_Spresense
 * License: MIT
 */

import java.util.Random;
import java.util.ArrayList;
import java.util.HashMap;
import javax.sound.midi.Sequence;
import javax.sound.midi.Track;
import javax.sound.midi.MidiEvent;
import javax.sound.midi.MidiMessage;
import javax.sound.midi.ShortMessage;
import javax.sound.midi.MetaMessage;

String[] aMotifs = {
  "A01_emotional_rise.mid", "A02_straight_pop.mid", "A03_longtone.mid", "A04_rhythm_hook.mid", "A05_arch.mid",
  "A06_call_response.mid", "A07_low_groove.mid", "A08_delayed_peak.mid", "A09_minimal.mid", "A10_open_end.mid"
};
String[] bMotifs = {
  "B01_emotional_lift.mid", "B02_straight_pop.mid", "B03_longtone.mid", "B04_rhythm_drive.mid", "B05_arch.mid",
  "B06_call_response.mid", "B07_low_to_mid.mid", "B08_delayed_peak.mid", "B09_minimal.mid", "B10_open_end.mid"
};
String[] cMotifs = {
  "C01_emotional_hook.mid", "C02_straight_hook.mid", "C03_longtone.mid", "C04_rhythm_push.mid", "C05_arch.mid",
  "C06_call_response.mid", "C07_mid_high_groove.mid", "C08_late_peak.mid", "C09_minimal_repeat.mid", "C10_open_end.mid"
};

String[] requiredBaseMidiFiles() {
  String[] files = new String[aMotifs.length + bMotifs.length + cMotifs.length];
  int offset = 0;
  System.arraycopy(aMotifs, 0, files, offset, aMotifs.length);
  offset += aMotifs.length;
  System.arraycopy(bMotifs, 0, files, offset, bMotifs.length);
  offset += bMotifs.length;
  System.arraycopy(cMotifs, 0, files, offset, cMotifs.length);
  return files;
}

String lastRandomA = "";
String lastRandomB = "";
String lastRandomC = "";
int lastRandomBaseIndex = -1;
Random generationRng = new Random(System.nanoTime());

int lastGeneratedMeterIndex = -1;
int lastGeneratedBpmIndex = -1;
String lastGeneratedChordMood = "balanced";
String lastAutoChordMood = "";
String chordMood = "balanced";
String[] randomChordMoods = {"balanced", "sad", "powerful", "bitter", "okinawa", "open", "city", "mystic", "gentle"};
int[] progressionA = {0, 4, 5, 3};
int[] progressionB = {5, 3, 0, 4};
int[] progressionC = {0, 4, 5, 4};
int[] progressionA_sad = {5, 3, 1, 4};
int[] progressionB_sad = {5, 1, 3, 4};
int[] progressionC_sad = {5, 3, 0, 1};
int[] progressionA_powerful = {0, 4, 3, 4};
int[] progressionB_powerful = {0, 4, 5, 4};
int[] progressionC_powerful = {0, 4, 0, 5};
int[] progressionA_bitter = {0, 5, 3, 4};
int[] progressionB_bitter = {5, 0, 4, 3};
int[] progressionC_bitter = {3, 5, 0, 4};
int[] progressionA_okinawa = {0, 3, 5, 3};
int[] progressionB_okinawa = {0, 5, 3, 4};
int[] progressionC_okinawa = {0, 3, 4, 5};
int[] progressionA_open = {0, 4, 5, 0};
int[] progressionB_open = {0, 5, 4, 0};
int[] progressionC_open = {0, 4, 0, 5};
int[] progressionA_city = {0, 5, 3, 4};
int[] progressionB_city = {3, 4, 0, 5};
int[] progressionC_city = {0, 4, 3, 5};
int[] progressionA_mystic = {0, 1, 5, 3};
int[] progressionB_mystic = {1, 5, 3, 4};
int[] progressionC_mystic = {0, 3, 1, 5};
int[] progressionA_gentle = {0, 3, 4, 5};
int[] progressionB_gentle = {0, 4, 3, 5};
int[] progressionC_gentle = {0, 5, 4, 3};
int[][] progressionOrdersA = {{0, 1, 2, 3}, {0, 2, 1, 3}, {0, 1, 3, 2}};
int[][] progressionOrdersB = {{0, 1, 2, 3}, {1, 0, 2, 3}, {0, 2, 3, 1}, {2, 1, 0, 3}, {0, 3, 1, 2}};
int[][] progressionOrdersC = {{0, 1, 2, 3}, {0, 1, 3, 2}, {0, 2, 1, 3}};
int currentProgVarA = 0;
int currentProgVarB = 0;
int currentProgVarC = 0;
int lastGeneratedChordDegree = 0;
String lastProgressionProfile = "A0/B0/C0";

int pickOneStepDirection(int index, int length) {
  if (length <= 1) return 0;
  if (index <= 0) return 1;
  if (index >= length - 1) return -1;
  return random(1) < 0.5 ? -1 : 1;
}

String randomChordMood() {
  return randomChordMoods[(int)random(randomChordMoods.length)];
}

String pickNextDistinctSongMood() {
  String picked = randomChordMood();
  int tries = 0;
  while (picked.equals(lastGeneratedChordMood) && tries < randomChordMoods.length * 8) {
    picked = randomChordMood();
    tries++;
  }
  lastGeneratedChordMood = picked;
  return picked;
}

void chooseProgressionProfileForSong() {
  currentProgVarA = pickRandomAvoidInt(progressionOrdersA.length, currentProgVarA);
  currentProgVarB = pickRandomAvoidInt(progressionOrdersB.length, currentProgVarB);
  currentProgVarC = pickRandomAvoidInt(progressionOrdersC.length, currentProgVarC);
  lastProgressionProfile = "A" + currentProgVarA + "/B" + currentProgVarB + "/C" + currentProgVarC;
}

int pickRandomAvoidInt(int count, int avoid) {
  if (count <= 1) return 0;
  int picked = (int)random(count);
  int tries = 0;
  while (picked == avoid && tries < 10) {
    picked = (int)random(count);
    tries++;
  }
  return picked;
}

String detectSectionFromFileName(String name) {
  if (name == null) return "";
  if (name.startsWith("A") || name.indexOf("_A") >= 0) return "A";
  if (name.startsWith("B") || name.indexOf("_B") >= 0) return "B";
  if (name.startsWith("C") || name.indexOf("chorus") >= 0) return "chorus";
  return "";
}

boolean isChordBoundarySlot(int inBarSlot) {
  String meter = meterOptions[meterIndex];
  if (meter.equals("2/4")) return inBarSlot == 0 || inBarSlot == 2;
  if (meter.equals("3/4")) return inBarSlot == 0 || inBarSlot == 2 || inBarSlot == 4;
  if (meter.equals("4/4")) return inBarSlot == 0 || inBarSlot == 4;
  if (meter.equals("6/8")) return inBarSlot == 0 || inBarSlot == 3;
  if (meter.equals("12/8")) return inBarSlot == 0 || inBarSlot == 3 || inBarSlot == 6 || inBarSlot == 9;
  if (meter.equals("5/4")) return inBarSlot == 0 || inBarSlot == 4 || inBarSlot == 8;
  if (meter.equals("7/8")) return inBarSlot == 0 || inBarSlot == 2 || inBarSlot == 4;
  return inBarSlot == 0 || inBarSlot == 3 || inBarSlot == 6;
}

boolean isKickSlot(int inBarSlot) {
  String meter = meterOptions[meterIndex];
  if (meter.equals("2/4") || meter.equals("3/4")) return inBarSlot == 0;
  if (meter.equals("4/4")) return inBarSlot == 0 || inBarSlot == 4;
  if (meter.equals("6/8")) return inBarSlot == 0 || inBarSlot == 3;
  if (meter.equals("12/8")) return inBarSlot == 0 || inBarSlot == 6;
  if (meter.equals("5/4")) return inBarSlot == 0 || inBarSlot == 4 || inBarSlot == 8;
  if (meter.equals("7/8")) return inBarSlot == 0 || inBarSlot == 4;
  return inBarSlot == 0 || inBarSlot == 3 || inBarSlot == 6;
}

boolean isSnareSlot(int inBarSlot) {
  String meter = meterOptions[meterIndex];
  if (meter.equals("2/4")) return inBarSlot == 2;
  if (meter.equals("3/4")) return inBarSlot == 4;
  if (meter.equals("4/4")) return inBarSlot == 2 || inBarSlot == 6;
  if (meter.equals("6/8")) return inBarSlot == 3;
  if (meter.equals("12/8")) return inBarSlot == 3 || inBarSlot == 9;
  if (meter.equals("5/4")) return inBarSlot == 2 || inBarSlot == 6;
  if (meter.equals("7/8")) return inBarSlot == 2 || inBarSlot == 5;
  return inBarSlot == 3 || inBarSlot == 7;
}

boolean isHatSlot(int inBarSlot) {
  String meter = meterOptions[meterIndex];
  if (meter.equals("4/4") || meter.equals("2/4") || meter.equals("3/4") || meter.equals("5/4")) {
    return (inBarSlot % 2) == 0;
  }
  return true;
}

boolean isAccentFillSlot(int inBarSlot) {
  return inBarSlot == max(0, slotsPerBar - 2);
}

int pickChordDegree(String section, int slot, int targetPc) {
  int harmonicStepSlots = max(1, phraseSlots / 4);
  int harmonicIndex = (slot / harmonicStepSlots) % 4;
  int[] progression = progressionForSection(section);
  int preferred = progression[harmonicIndex % progression.length];

  if (targetPc < 0 || chordContainsPc(preferred, targetPc)) {
    lastGeneratedChordDegree = preferred;
    return preferred;
  }

  int bestDegree = preferred;
  int bestScore = 9999;
  for (int degree = 0; degree < 7; degree++) {
    if (!chordContainsPc(degree, targetPc)) continue;
    int preferredDistance = circularDegreeDistance(degree, preferred);
    int previousDistance = circularDegreeDistance(degree, lastGeneratedChordDegree);
    int score = preferredDistance * 3 + previousDistance;
    if (degree == 6) score += 4;
    if (score < bestScore) {
      bestScore = score;
      bestDegree = degree;
    }
  }
  lastGeneratedChordDegree = bestDegree;
  return bestDegree;
}

int scaleDegreeToMidiRoot(int degree, int rootC) {
  int[] scale = {0, 2, 4, 5, 7, 9, 11};
  return rootC + scale[degree % 7] + (degree / 7) * 12;
}

String qualityForDegree(int degree) {
  return qualityForDegree(degree, "", 0);
}

String qualityForDegree(int degree, String section, int slotInPhrase) {
  boolean chorus = section != null && section.equals("chorus");
  int inBarSlot = slotInPhrase % max(1, slotsPerBar);

  if (chorus && !chordMood.equals("okinawa")) {
    if ((degree == 0 || degree == 4) && (inBarSlot % 2 == 1)) return "add9";
    if (degree == 3 && (inBarSlot == 1 || inBarSlot == max(1, slotsPerBar / 2) + 1)) return "sus4";
  }
  if (chordMood.equals("sad") && degree == 4) return "minor";
  if (chordMood.equals("bitter")) {
    if (degree == 0 || degree == 4) return "major6";
    if (degree == 3 || degree == 5) return "minor6";
  }
  if (chordMood.equals("okinawa")) return degree == 0 || degree == 5 || degree == 3 ? "sus2" : "sus4";
  if (chordMood.equals("open")) return degree == 0 || degree == 4 ? "major6" : "sus4";
  if (chordMood.equals("city")) {
    if (degree == 0 || degree == 3 || degree == 4) return "add9";
    if (degree == 5) return "minor6";
  }
  if (chordMood.equals("mystic")) return degree == 0 || degree == 1 || degree == 3 ? "sus4" : "sus2";
  if (chordMood.equals("gentle")) {
    if (degree == 0 || degree == 4) return "major6";
    if (degree == 3 || degree == 5) return "minor6";
  }
  if (degree == 1 || degree == 2 || degree == 5) return "minor";
  if (degree == 6) return "diminished";
  return "major";
}

void applyChordVoicingVariant(int[] chordNotes, int variantSeed) {
  if (chordNotes == null || chordNotes.length < 3) return;
  int variant = variantSeed % 4;
  if (variant == 1) {
    int index = min(2, chordNotes.length - 1);
    chordNotes[index] = min(96, chordNotes[index] + 12);
  } else if (variant == 2) {
    int index = min(1, chordNotes.length - 1);
    chordNotes[index] = max(36, chordNotes[index] - 12);
  } else if (variant == 3) {
    int index = chordNotes.length - 1;
    chordNotes[index] = min(96, chordNotes[index] + 12);
  }
  sortIntArrayAsc(chordNotes);
}

void sortIntArrayAsc(int[] values) {
  if (values == null) return;
  for (int i = 0; i < values.length - 1; i++) {
    for (int j = i + 1; j < values.length; j++) {
      if (values[j] < values[i]) {
        int temp = values[i];
        values[i] = values[j];
        values[j] = temp;
      }
    }
  }
}

int[] chordVelocitiesForMood(int count) {
  int[] velocities = new int[count];
  int[] base;
  if (chordMood.equals("sad")) base = new int[] {48, 44, 40, 38, 34};
  else if (chordMood.equals("powerful")) base = new int[] {64, 60, 56, 52, 48};
  else if (chordMood.equals("bitter")) base = new int[] {54, 50, 46, 44, 40};
  else if (chordMood.equals("okinawa")) base = new int[] {52, 48, 46, 42, 38};
  else if (chordMood.equals("open")) base = new int[] {58, 54, 50, 46, 42};
  else if (chordMood.equals("city")) base = new int[] {56, 52, 48, 44, 40};
  else if (chordMood.equals("mystic")) base = new int[] {50, 46, 42, 38, 34};
  else if (chordMood.equals("gentle")) base = new int[] {52, 48, 44, 40, 36};
  else base = new int[] {58, 54, 50, 46, 42};
  for (int i = 0; i < count; i++) velocities[i] = base[min(i, base.length - 1)];
  return velocities;
}

boolean chordContainsPc(int degree, int targetPc) {
  int rootPc = scaleDegreeToMidiRoot(degree, 0) % 12;
  int[] pitchClasses;
  if (degree == 1 || degree == 2 || degree == 5) pitchClasses = new int[] {rootPc, (rootPc + 3) % 12, (rootPc + 7) % 12};
  else if (degree == 6) pitchClasses = new int[] {rootPc, (rootPc + 3) % 12, (rootPc + 6) % 12};
  else pitchClasses = new int[] {rootPc, (rootPc + 4) % 12, (rootPc + 7) % 12};
  for (int pitchClass : pitchClasses) if (pitchClass == targetPc % 12) return true;
  return false;
}

int circularDegreeDistance(int first, int second) {
  int distance = abs(first - second);
  return min(distance, 7 - distance);
}

int[] progressionForSection(String section) {
  int[] base = baseProgressionForSection(section);
  int[] order = progressionOrderForSection(section);
  if (base == null || base.length == 0) return new int[] {0, 4, 5, 3};
  if (order == null || order.length == 0) return base;
  int[] progression = new int[order.length];
  for (int i = 0; i < order.length; i++) {
    int index = ((order[i] % base.length) + base.length) % base.length;
    progression[i] = base[index];
  }
  return progression;
}

int[] progressionOrderForSection(String section) {
  if (section.equals("A")) return progressionOrdersA[currentProgVarA % progressionOrdersA.length];
  if (section.equals("B")) return progressionOrdersB[currentProgVarB % progressionOrdersB.length];
  return progressionOrdersC[currentProgVarC % progressionOrdersC.length];
}

int[] baseProgressionForSection(String section) {
  if (chordMood.equals("sad")) {
    if (section.equals("A")) return progressionA_sad;
    if (section.equals("B")) return progressionB_sad;
    return progressionC_sad;
  }
  if (chordMood.equals("bitter")) {
    if (section.equals("A")) return progressionA_bitter;
    if (section.equals("B")) return progressionB_bitter;
    return progressionC_bitter;
  }
  if (chordMood.equals("okinawa")) {
    if (section.equals("A")) return progressionA_okinawa;
    if (section.equals("B")) return progressionB_okinawa;
    return progressionC_okinawa;
  }
  if (chordMood.equals("open")) {
    if (section.equals("A")) return progressionA_open;
    if (section.equals("B")) return progressionB_open;
    return progressionC_open;
  }
  if (chordMood.equals("powerful")) {
    if (section.equals("A")) return progressionA_powerful;
    if (section.equals("B")) return progressionB_powerful;
    return progressionC_powerful;
  }
  if (chordMood.equals("city")) {
    if (section.equals("A")) return progressionA_city;
    if (section.equals("B")) return progressionB_city;
    return progressionC_city;
  }
  if (chordMood.equals("mystic")) {
    if (section.equals("A")) return progressionA_mystic;
    if (section.equals("B")) return progressionB_mystic;
    return progressionC_mystic;
  }
  if (chordMood.equals("gentle")) {
    if (section.equals("A")) return progressionA_gentle;
    if (section.equals("B")) return progressionB_gentle;
    return progressionC_gentle;
  }
  if (section.equals("A")) return progressionA;
  if (section.equals("B")) return progressionB;
  return progressionC;
}

class GeneratedSong {
  Sequence sequence;
  String[] baseFiles;
  MelodyTransform transform;
  String chordMood;
  String progressionProfile;
  String label;
  int meterIndexForSong;
  int bpmIndexForSong;
  int progVarAForSong;
  int progVarBForSong;
  int progVarCForSong;
  int[] progressionAForSong;
  int[] progressionBForSong;
  int[] progressionCForSong;

  GeneratedSong(
    Sequence sequence,
    String[] baseFiles,
    MelodyTransform transform,
    String chordMood,
    String progressionProfile,
    String label,
    int meterIndexForSong,
    int bpmIndexForSong,
    int progVarAForSong,
    int progVarBForSong,
    int progVarCForSong,
    int[] progressionAForSong,
    int[] progressionBForSong,
    int[] progressionCForSong
  ) {
    this.sequence = sequence;
    this.baseFiles = baseFiles;
    this.transform = transform;
    this.chordMood = chordMood;
    this.progressionProfile = progressionProfile;
    this.label = label;
    this.meterIndexForSong = meterIndexForSong;
    this.bpmIndexForSong = bpmIndexForSong;
    this.progVarAForSong = progVarAForSong;
    this.progVarBForSong = progVarBForSong;
    this.progVarCForSong = progVarCForSong;
    this.progressionAForSong = progressionAForSong;
    this.progressionBForSong = progressionBForSong;
    this.progressionCForSong = progressionCForSong;
  }
}

GeneratedSong generateRhythmBaseSong(HashMap<String, Sequence> baseMidiTable, int sets) {
  if (baseMidiTable == null || baseMidiTable.isEmpty()) {
    println("Loaded base MIDI table is empty.");
    return null;
  }

  String songMood = pickNextDistinctSongMood();
  chordMood = songMood;
  lastAutoChordMood = songMood;

  int exportMeterIndex = pickNextDistinctSongMeterIndex();
  int exportBpmIndex = pickNextDistinctSongBpmIndex();
  meterIndex = exportMeterIndex;
  bpmIndex = exportBpmIndex;
  applyMeterByIndex(exportMeterIndex);
  applyBpmByIndex(exportBpmIndex);

  chooseProgressionProfileForSong();
  int songProgVarA = currentProgVarA;
  int songProgVarB = currentProgVarB;
  int songProgVarC = currentProgVarC;
  int[] songProgressionA = progressionForSection("A");
  int[] songProgressionB = progressionForSection("B");
  int[] songProgressionC = progressionForSection("C");
  lastGeneratedChordDegree = 0;

  String[] files = buildRandomSequence(sets);
  if (files == null || files.length == 0) {
    println("Generated base file list is empty.");
    return null;
  }

  MelodyTransform transform = randomMelodyTransform();
  ArrayList<SectionSpan> spans = new ArrayList<SectionSpan>();
  Sequence combined = buildRhythmBaseSequence(baseMidiTable, files, transform, spans);
  if (combined == null) {
    return null;
  }

  try {
    addGeneratedTempoAndTimeSignature(combined, exportMeterIndex, exportBpmIndex);
  } catch (Exception e) {
    println("Failed to prepare generated MIDI: " + e.getMessage());
    return null;
  }
  printMidiMetaDebug(combined, "GENERATED", exportMeterIndex, exportBpmIndex);

  return new GeneratedSong(
    combined,
    files,
    transform,
    chordMood,
    lastProgressionProfile,
    "rhythm-base x" + sets + " / " + transform.summary(),
    exportMeterIndex,
    exportBpmIndex,
    songProgVarA,
    songProgVarB,
    songProgVarC,
    songProgressionA,
    songProgressionB,
    songProgressionC
  );
}

String[] buildRandomSequence(int sets) {
  String[] sequence = new String[sets * 5];
  int candidateCount = min(aMotifs.length, min(bMotifs.length, cMotifs.length));
  if (candidateCount <= 0) {
    return sequence;
  }

  String previousA = lastRandomA;
  String previousB = lastRandomB;
  String previousC = lastRandomC;
  int index = 0;

  for (int set = 0; set < sets; set++) {
    int aIndex = generationRng.nextInt(candidateCount);
    int bIndex = generationRng.nextInt(candidateCount);
    int cIndex = generationRng.nextInt(candidateCount);
    int attempts = 0;

    while ((aIndex == lastRandomBaseIndex || aIndex == bIndex || aIndex == cIndex) && attempts < candidateCount * 8) {
      aIndex = generationRng.nextInt(candidateCount);
      attempts++;
    }
    attempts = 0;
    while (bIndex == aIndex && attempts < candidateCount * 8) {
      bIndex = generationRng.nextInt(candidateCount);
      attempts++;
    }
    attempts = 0;
    while (cIndex == aIndex || cIndex == bIndex) {
      cIndex = generationRng.nextInt(candidateCount);
      attempts++;
      if (attempts > candidateCount * 8) {
        break;
      }
    }

    String a = aMotifs[aIndex];
    String b = bMotifs[bIndex];
    String c = cMotifs[cIndex];

    attempts = 0;
    while (a.equals(previousA) && b.equals(previousB) && c.equals(previousC) && attempts < candidateCount * 8) {
      aIndex = generationRng.nextInt(candidateCount);
      bIndex = generationRng.nextInt(candidateCount);
      cIndex = generationRng.nextInt(candidateCount);
      a = aMotifs[aIndex];
      b = bMotifs[bIndex];
      c = cMotifs[cIndex];
      attempts++;
    }

    previousA = a;
    previousB = b;
    previousC = c;
    lastRandomA = a;
    lastRandomB = b;
    lastRandomC = c;
    lastRandomBaseIndex = aIndex;

    sequence[index++] = a;
    sequence[index++] = a;
    sequence[index++] = b;
    sequence[index++] = c;
    sequence[index++] = b;
  }

  return sequence;
}

int pickNextDistinctSongMeterIndex() {
  if (meterOptions == null || meterOptions.length <= 1) {
    return 0;
  }

  if (random(1) < autoShiftKeepProbability) {
    int keep = constrain(meterIndex, 0, meterOptions.length - 1);
    lastGeneratedMeterIndex = keep;
    return keep;
  }

  int step = pickOneStepDirection(meterIndex, meterOptions.length);
  int chosen = constrain(meterIndex + step, 0, meterOptions.length - 1);
  if (chosen == lastGeneratedMeterIndex && meterOptions.length > 1) {
    chosen = constrain(chosen + (step == 0 ? 1 : -step), 0, meterOptions.length - 1);
  }

  lastGeneratedMeterIndex = chosen;
  return chosen;
}

int pickNextDistinctSongBpmIndex() {
  if (bpmOptions == null || bpmOptions.length <= 1) {
    return 0;
  }

  if (random(1) < autoShiftKeepProbability) {
    int keep = constrain(bpmIndex, 0, bpmOptions.length - 1);
    lastGeneratedBpmIndex = keep;
    return keep;
  }

  int step = pickOneStepDirection(bpmIndex, bpmOptions.length);
  int chosen = constrain(bpmIndex + step, 0, bpmOptions.length - 1);
  if (chosen == lastGeneratedBpmIndex && bpmOptions.length > 1) {
    chosen = constrain(chosen + (step == 0 ? 1 : -step), 0, bpmOptions.length - 1);
  }

  lastGeneratedBpmIndex = chosen;
  return chosen;
}

void addGeneratedTempoAndTimeSignature(Sequence seq, int meterIndexForExport, int bpmIndexForExport) {
  if (seq == null || seq.getTracks() == null || seq.getTracks().length == 0) {
    return;
  }

  Track metaTrack = seq.createTrack();
  int numerator = 4;
  int denominatorPower = 2;
  String meter = meterOptions[(int)constrain(meterIndexForExport, 0, meterOptions.length - 1)];

  if (meter.equals("2/4")) {
    numerator = 2; denominatorPower = 2;
  } else if (meter.equals("3/4")) {
    numerator = 3; denominatorPower = 2;
  } else if (meter.equals("4/4")) {
    numerator = 4; denominatorPower = 2;
  } else if (meter.equals("6/8")) {
    numerator = 6; denominatorPower = 3;
  } else if (meter.equals("12/8")) {
    numerator = 12; denominatorPower = 3;
  } else if (meter.equals("5/4")) {
    numerator = 5; denominatorPower = 2;
  } else if (meter.equals("7/8")) {
    numerator = 7; denominatorPower = 3;
  } else {
    numerator = 9; denominatorPower = 3;
  }

  int bpm = bpmOptions[(int)constrain(bpmIndexForExport, 0, bpmOptions.length - 1)];
  int microsPerQuarter = 60000000 / max(1, bpm);
  byte[] tempoData = new byte[] {
    (byte)((microsPerQuarter >> 16) & 0xFF),
    (byte)((microsPerQuarter >> 8) & 0xFF),
    (byte)(microsPerQuarter & 0xFF)
  };

  try {
    MetaMessage tempo = new MetaMessage();
    tempo.setMessage(0x51, tempoData, tempoData.length);
    metaTrack.add(new MidiEvent(tempo, 0));

    byte[] timeSig = new byte[] {
      (byte)numerator,
      (byte)denominatorPower,
      (byte)24,
      (byte)8
    };
    MetaMessage ts = new MetaMessage();
    ts.setMessage(0x58, timeSig, timeSig.length);
    metaTrack.add(new MidiEvent(ts, 0));
  } catch (Exception e) {
    println("Failed to add tempo/time-signature metadata: " + e.getMessage());
  }
}

void printMidiMetaDebug(Sequence seq, String label, int expectedMeterIndex, int expectedBpmIndex) {
  if (seq == null) {
    return;
  }

  try {
    int tempoBpm = -1;
    String meterText = "unknown";

    Track[] tracks = seq.getTracks();
    for (int t = 0; t < tracks.length; t++) {
      Track tr = tracks[t];
      for (int i = 0; i < tr.size(); i++) {
        MidiEvent ev = tr.get(i);
        MidiMessage msg = ev.getMessage();
        if (!(msg instanceof MetaMessage)) {
          continue;
        }
        MetaMessage mm = (MetaMessage)msg;
        if (mm.getType() == 0x51) {
          byte[] data = mm.getData();
          if (data != null && data.length >= 3) {
            int usPerQuarter = ((data[0] & 0xFF) << 16) | ((data[1] & 0xFF) << 8) | (data[2] & 0xFF);
            tempoBpm = 60000000 / max(1, usPerQuarter);
          }
        }
        if (mm.getType() == 0x58) {
          byte[] data = mm.getData();
          if (data != null && data.length >= 2) {
            int num = data[0] & 0xFF;
            int denPow = data[1] & 0xFF;
            int den = 1 << denPow;
            meterText = num + "/" + den;
          }
        }
      }
    }

    println("[META] " + label +
      " expectedMeter=" + meterOptions[expectedMeterIndex] +
      " expectedBpm=" + bpmOptions[expectedBpmIndex] +
      " actualMeter=" + meterText +
      " actualBpm=" + tempoBpm);
  } catch (Exception e) {
    println("[META] failed to inspect generated MIDI: " + e.getMessage());
  }
}

Sequence buildRhythmBaseSequence(HashMap<String, Sequence> baseMidiTable, String[] files, MelodyTransform transform, ArrayList<SectionSpan> outSpans) {
  try {
    Sequence combined = new Sequence(Sequence.PPQ, 480);
    Track melodyTrack = combined.createTrack();
    Track chordTrack = combined.createTrack();
    Track drumTrack = combined.createTrack();

    long bridgeOverlapTicks = chordSlotTicks * 2L;
    long bridgeRepeatTicks = chordSlotTicks * 2L;

    Sequence prevSrc = null;
    ClipRange prevRange = null;
    String prevSection = "";

    long offset = 0;
    for (int i = 0; i < files.length; i++) {
      Sequence src = baseMidiTable.get(files[i]);
      if (src == null) {
        println("Skip missing loaded MIDI: " + files[i]);
        offset += phraseTicks;
        continue;
      }

      ClipRange range = detectContentRange(src);
      String section = detectSectionFromFileName(files[i]);

      // At section joins, replay the previous tail and overlap the next intro as a soft bridge.
      if (i > 0 && prevSrc != null && prevRange != null) {
        long prevTailStart = Math.max(prevRange.startTick, prevRange.endTickExclusive - bridgeRepeatTicks);
        long curHeadEnd = Math.min(range.endTickExclusive, range.startTick + bridgeRepeatTicks);
        long bridgeStart = Math.max(0L, offset - bridgeOverlapTicks);

        copySequenceIntoTrackTransformed(
          prevSrc,
          melodyTrack,
          bridgeStart,
          prevTailStart,
          prevRange.endTickExclusive,
          false,
          transform,
          prevSection,
          0.72f
        );

        copySequenceIntoTrackTransformed(
          src,
          melodyTrack,
          bridgeStart,
          range.startTick,
          curHeadEnd,
          false,
          transform,
          section,
          0.58f
        );
      }

      copySequenceIntoTrackTransformed(src, melodyTrack, offset, range.startTick, range.endTickExclusive, i == 0, transform, section, 1.0f);

      int startSlot = (int)(offset / chordSlotTicks);
      int endSlotExclusive = startSlot + phraseSlots;
      outSpans.add(new SectionSpan(startSlot, endSlotExclusive, section));

      prevSrc = src;
      prevRange = range;
      prevSection = section;
      offset += phraseTicks;
    }

    addArrangementTracks(combined, melodyTrack, chordTrack, drumTrack, outSpans, offset);

    MetaMessage eot = new MetaMessage();
    eot.setMessage(0x2F, new byte[0], 0);
    melodyTrack.add(new MidiEvent(eot, offset));
    chordTrack.add(new MidiEvent((MidiMessage)eot.clone(), offset));
    drumTrack.add(new MidiEvent((MidiMessage)eot.clone(), offset));
    return combined;
  } catch (Exception e) {
    println("Failed to build rhythm-base sequence: " + e.getMessage());
    return null;
  }
}

void addArrangementTracks(Sequence combined, Track melodyTrack, Track chordTrack, Track drumTrack, ArrayList<SectionSpan> spans, long totalTicks) {
  if (combined == null || melodyTrack == null || chordTrack == null || drumTrack == null) {
    return;
  }

  int totalSlots = max(1, (int)((totalTicks + chordSlotTicks - 1) / chordSlotTicks));
  int[] leadPcBySlot = buildLeadPcTimeline(melodyTrack, totalSlots);

  // Chord timbre = Nylon Guitar (GM program 24) on channel 1.
  addProgramChange(chordTrack, 1, 24, 0);

  for (int slot = 0; slot < totalSlots; slot++) {
    String section = detectSectionAtSlotFrom(spans, slot);
    if (section.length() == 0) {
      section = "A";
    }

    int inBarSlot = slot % max(1, slotsPerBar);
    int targetPc = leadPcBySlot[slot];
    int degree = pickChordDegree(section, slot, targetPc);
    String quality = qualityForDegree(degree, section, slot % max(1, phraseSlots));
    int root = scaleDegreeToMidiRoot(degree, 48);
    int[] chordNotes = buildChordNotesForExport(root, quality, slot);
    int[] chordVels = chordVelocitiesForMood(chordNotes.length);

    long startTick = (long)slot * chordSlotTicks;
    long endTick = Math.min(Math.max(startTick + 30L, totalTicks - 1L), startTick + (long)chordSlotTicks - 1L);

    for (int i = 0; i < chordNotes.length; i++) {
      int vel = chordVels[min(i, chordVels.length - 1)];
      addMidiNote(chordTrack, 1, chordNotes[i], vel, startTick, endTick);
    }

    // Drum pattern generated on slot grid to keep section continuity.
    if (isKickSlot(inBarSlot)) {
      addPercHit(drumTrack, 36, section.equals("chorus") ? 108 : 96, startTick);
    }
    if (isSnareSlot(inBarSlot)) {
      addPercHit(drumTrack, 38, section.equals("chorus") ? 98 : 90, startTick);
    }
    if (isHatSlot(inBarSlot)) {
      int hatVel = section.equals("chorus") ? 82 : (section.equals("B") ? 74 : 66);
      addPercHit(drumTrack, 42, hatVel, startTick);
    }
    if (section.equals("chorus") && isAccentFillSlot(inBarSlot)) {
      addPercHit(drumTrack, 46, 74, startTick + max(1, chordSlotTicks / 2));
    }
  }
}

int[] buildLeadPcTimeline(Track melodyTrack, int totalSlots) {
  int[] pcs = new int[totalSlots];
  for (int i = 0; i < totalSlots; i++) {
    pcs[i] = -1;
  }

  for (int i = 0; i < melodyTrack.size(); i++) {
    MidiEvent ev = melodyTrack.get(i);
    MidiMessage msg = ev.getMessage();
    if (!(msg instanceof ShortMessage)) {
      continue;
    }

    ShortMessage sm = (ShortMessage)msg;
    int cmd = sm.getCommand();
    int ch = sm.getChannel();
    int vel = sm.getData2();
    if (ch == 9) {
      continue;
    }
    if (!(cmd == ShortMessage.NOTE_ON && vel > 0)) {
      continue;
    }

    int slot = (int)(ev.getTick() / chordSlotTicks);
    if (slot < 0 || slot >= totalSlots) {
      continue;
    }
    if (pcs[slot] < 0) {
      pcs[slot] = sm.getData1() % 12;
    }
  }

  int last = -1;
  for (int i = 0; i < totalSlots; i++) {
    if (pcs[i] >= 0) {
      last = pcs[i];
    } else if (last >= 0) {
      pcs[i] = last;
    }
  }
  return pcs;
}

String detectSectionAtSlotFrom(ArrayList<SectionSpan> spans, int slotGlobal) {
  if (spans == null) {
    return "";
  }
  for (int i = 0; i < spans.size(); i++) {
    SectionSpan s = spans.get(i);
    if (slotGlobal >= s.startSlot && slotGlobal < s.endSlotExclusive) {
      return s.section;
    }
  }
  return "";
}

int[] buildChordNotesForExport(int root, String quality, int slotSeed) {
  int third = 4;
  int fifth = 7;
  int second = 2;
  int fourth = 5;
  int sixth = 9;
  int ninth = 14;

  if (quality.equals("minor")) {
    third = 3;
  } else if (quality.equals("diminished")) {
    third = 3;
    fifth = 6;
  } else if (quality.equals("sus2")) {
    third = 2;
    fifth = 7;
  } else if (quality.equals("sus4")) {
    third = 5;
    fifth = 7;
  } else if (quality.equals("minor6")) {
    third = 3;
    sixth = 9;
  }

  int[] notes;
  if (chordMood.equals("okinawa")) {
    if (quality.equals("sus4")) {
      notes = new int[] {root - 12, root, root + fifth, root + 12 + fourth};
    } else {
      notes = new int[] {root - 12, root, root + fifth, root + 12 + second};
    }
  } else if (chordMood.equals("powerful")) {
    notes = new int[] {root - 12, root, root + fifth, root + third, root + 12};
  } else if (quality.equals("sus2")) {
    notes = new int[] {root, root + second, root + fifth, root + 12};
  } else if (quality.equals("sus4")) {
    notes = new int[] {root, root + fourth, root + fifth, root + 12};
  } else if (quality.equals("major6") || quality.equals("minor6") || quality.equals("add6")) {
    notes = new int[] {root, root + fifth, root + third, root + sixth, root + 12};
  } else if (quality.equals("add9")) {
    notes = new int[] {root, root + fifth, root + third, root + ninth, root + 12};
  } else {
    notes = new int[] {root, root + fifth, root + third, root + 12};
  }

  applyChordVoicingVariant(notes, slotSeed + 1);
  return notes;
}

MelodyTransform randomMelodyTransform() {
  int[] transposeOptions = {-2, -1, 0, 1, 2};
  int transpose = transposeOptions[(int)random(transposeOptions.length)];
  float velocityScale = random(1.08, 1.28);
  float gateScale = random(0.95, 1.10);
  int[] swingOptions = {0, 0, 6, 12, 18, 24, -12};
  int swingTicks = swingOptions[(int)random(swingOptions.length)];
  float dropoutRate = random(0.00, 0.05);

  if (chordMood != null) {
    if (chordMood.equals("powerful")) {
      velocityScale = random(1.18, 1.40);
      gateScale = random(0.98, 1.18);
      swingTicks = 12;
      dropoutRate = random(0.00, 0.03);
    } else if (chordMood.equals("gentle")) {
      velocityScale = random(0.96, 1.18);
      gateScale = random(0.90, 1.02);
      swingTicks = 0;
      dropoutRate = random(0.02, 0.08);
    } else if (chordMood.equals("sad")) {
      velocityScale = random(1.00, 1.24);
      gateScale = random(0.88, 1.04);
      swingTicks = 6;
      dropoutRate = random(0.04, 0.10);
    } else if (chordMood.equals("mystic") || chordMood.equals("city")) {
      velocityScale = random(1.06, 1.30);
      gateScale = random(0.94, 1.08);
      swingTicks = 12;
      dropoutRate = random(0.02, 0.06);
    }
  }

  return new MelodyTransform(transpose, velocityScale, gateScale, swingTicks, dropoutRate);
}

void copySequenceIntoTrackTransformed(
  Sequence src,
  Track dst,
  long tickOffset,
  long clipStartTick,
  long clipEndTickExclusive,
  boolean includeMetaAtStart,
  MelodyTransform transform,
  String section,
  float velocityGain
) {
  forcePianoProgram(dst, tickOffset);
  Track[] tracks = src.getTracks();
  for (int t = 0; t < tracks.length; t++) {
    Track tr = tracks[t];
    long[] noteOnOutTick = new long[128];
    int[] noteOutPitch = new int[128];
    boolean[] noteDropped = new boolean[128];
    for (int n = 0; n < 128; n++) {
      noteOnOutTick[n] = -1;
      noteOutPitch[n] = -1;
      noteDropped[n] = false;
    }

    for (int i = 0; i < tr.size(); i++) {
      MidiEvent ev = tr.get(i);
      MidiMessage msg = ev.getMessage();
      long tick = ev.getTick();
      if (msg instanceof MetaMessage) {
        MetaMessage meta = (MetaMessage)msg;
        if (meta.getType() == 0x2F) continue;
        if (includeMetaAtStart && tick == 0) {
          dst.add(new MidiEvent((MidiMessage)msg.clone(), tickOffset));
        }
        continue;
      }

      if (!(msg instanceof ShortMessage)) {
        if (tick >= clipStartTick && tick < clipEndTickExclusive) {
          long relTick = tick - clipStartTick;
          dst.add(new MidiEvent((MidiMessage)msg.clone(), applySwingTick(relTick, transform.swingTicks) + tickOffset));
        }
        continue;
      }
      if (tick < clipStartTick || tick >= clipEndTickExclusive) continue;

      ShortMessage midi = (ShortMessage)msg;
      int command = midi.getCommand();
      int channel = midi.getChannel();
      int note = midi.getData1();
      int velocity = midi.getData2();
      long relTick = tick - clipStartTick;
      boolean noteOn = command == ShortMessage.NOTE_ON && velocity > 0;
      boolean noteOff = command == ShortMessage.NOTE_OFF || (command == ShortMessage.NOTE_ON && velocity == 0);

      if (command == ShortMessage.PROGRAM_CHANGE && channel != 9) continue;

      if (noteOn && note >= 0 && note < 128) {
        int phraseSlot = constrain((int)(relTick / chordSlotTicks), 0, max(0, phraseSlots - 1));
        boolean protectBeat = isChordBoundarySlot(phraseSlot % max(1, slotsPerBar));
        noteDropped[note] = !protectBeat && random(1) < transform.dropoutRate;
        if (noteDropped[note]) continue;

        int outputPitch = constrain(note + transform.transpose, 36, 96);
        outputPitch = constrainPitchToHarmony(outputPitch, section, relTick);
        int outputVelocity = constrain((int)(velocity * transform.velocityScale * max(0.0f, velocityGain)), 1, 127);
        long outputTick = applySwingTick(relTick, transform.swingTicks) + tickOffset;
        try {
          ShortMessage output = new ShortMessage();
          output.setMessage(ShortMessage.NOTE_ON, channel, outputPitch, outputVelocity);
          dst.add(new MidiEvent(output, outputTick));
          noteOnOutTick[note] = outputTick;
          noteOutPitch[note] = outputPitch;
        } catch (Exception e) {
          println("note on transform failed: " + e.getMessage());
        }
        continue;
      }

      if (noteOff && note >= 0 && note < 128) {
        if (noteDropped[note]) {
          noteDropped[note] = false;
          continue;
        }
        if (noteOnOutTick[note] < 0 || noteOutPitch[note] < 0) continue;

        long idealOff = applySwingTick(relTick, transform.swingTicks) + tickOffset;
        long duration = Math.max(24L, (long)((idealOff - noteOnOutTick[note]) * transform.gateScale));
        long outputOffTick = Math.min(noteOnOutTick[note] + duration, tickOffset + phraseTicks - 1L);
        try {
          ShortMessage output = new ShortMessage();
          output.setMessage(ShortMessage.NOTE_OFF, channel, noteOutPitch[note], 0);
          dst.add(new MidiEvent(output, outputOffTick));
        } catch (Exception e) {
          println("note off transform failed: " + e.getMessage());
        }
        noteOnOutTick[note] = -1;
        noteOutPitch[note] = -1;
        continue;
      }

      try {
        ShortMessage output = new ShortMessage();
        output.setMessage(command, channel, midi.getData1(), midi.getData2());
        dst.add(new MidiEvent(output, applySwingTick(relTick, transform.swingTicks) + tickOffset));
      } catch (Exception e) {
        println("msg transform failed: " + e.getMessage());
      }
    }
  }
}

void forcePianoProgram(Track track, long tick) {
  try {
    ShortMessage programChange = new ShortMessage();
    programChange.setMessage(ShortMessage.PROGRAM_CHANGE, 0, 0, 0);
    track.add(new MidiEvent(programChange, tick));
  } catch (Exception e) {
    println("piano program set failed: " + e.getMessage());
  }
}

int constrainPitchToHarmony(int pitch, String section, long relTick) {
  int slotInPhrase = constrain((int)(relTick / chordSlotTicks), 0, max(0, phraseSlots - 1));
  int degree = preferredDegreeAtSlot(section, slotInPhrase);
  String quality = qualityForDegree(degree, section, slotInPhrase);
  int[] chordPcs = chordTonePcsForDegree(degree, quality);
  int[] scalePcs = scaleTonePcsForDegree(degree, quality);

  int pc = ((pitch % 12) + 12) % 12;
  boolean strongBeat = isChordBoundarySlot(slotInPhrase % max(1, slotsPerBar));
  int[] primaryPcs = strongBeat ? chordPcs : scalePcs;
  int[] secondaryPcs = strongBeat ? scalePcs : chordPcs;
  if (containsPitchClass(primaryPcs, pc)) return pitch;

  int bestPitch = pitch;
  int bestScore = Integer.MAX_VALUE;
  int tolerance = strongBeat ? 3 : 5;
  for (int i = 0; i < primaryPcs.length; i++) {
    int candidatePitch = nearestPitchForPc(pitch, primaryPcs[i]);
    int distance = abs(candidatePitch - pitch);
    int score = distance * 3 + (strongBeat ? 1 : 4);
    if (score < bestScore) {
      bestScore = score;
      bestPitch = constrain(candidatePitch, 36, 96);
    }
  }
  for (int i = 0; i < secondaryPcs.length; i++) {
    int candidatePitch = nearestPitchForPc(pitch, secondaryPcs[i]);
    int distance = abs(candidatePitch - pitch);
    int score = distance * 4 + (strongBeat ? 5 : 9);
    if (score < bestScore) {
      bestScore = score;
      bestPitch = constrain(candidatePitch, 36, 96);
    }
  }
  return abs(bestPitch - pitch) <= tolerance ? pitch : constrain(bestPitch, 36, 96);
}

boolean containsPitchClass(int[] pitchClasses, int value) {
  for (int pitchClass : pitchClasses) {
    if (pitchClass == value) return true;
  }
  return false;
}

int nearestPitchForPc(int aroundPitch, int targetPc) {
  int base = aroundPitch - (((aroundPitch % 12) + 12) % 12) + targetPc;
  int best = base;
  int bestDistance = abs(base - aroundPitch);
  int up = base + 12;
  if (abs(up - aroundPitch) < bestDistance) {
    best = up;
    bestDistance = abs(up - aroundPitch);
  }
  int down = base - 12;
  if (abs(down - aroundPitch) < bestDistance) best = down;
  return best;
}

int preferredDegreeAtSlot(String section, int slotInPhrase) {
  int[] progression = progressionForSection(section);
  int harmonicStepSlots = max(1, phraseSlots / 4);
  int harmonicIndex = (slotInPhrase / harmonicStepSlots) % 4;
  return progression[harmonicIndex % progression.length];
}

int[] chordTonePcsForDegree(int degree, String quality) {
  int rootPc = scaleDegreeToMidiRoot(degree, 0) % 12;
  if (quality.equals("add9")) return new int[] {rootPc, (rootPc + 2) % 12, (rootPc + 4) % 12, (rootPc + 7) % 12};
  if (quality.equals("diminished")) return new int[] {rootPc, (rootPc + 3) % 12, (rootPc + 6) % 12};
  if (quality.equals("minor") || quality.equals("minor6")) return new int[] {rootPc, (rootPc + 3) % 12, (rootPc + 7) % 12};
  if (quality.equals("sus2")) return new int[] {rootPc, (rootPc + 2) % 12, (rootPc + 7) % 12};
  if (quality.equals("sus4")) return new int[] {rootPc, (rootPc + 5) % 12, (rootPc + 7) % 12};
  return new int[] {rootPc, (rootPc + 4) % 12, (rootPc + 7) % 12};
}

int[] scaleTonePcsForDegree(int degree, String quality) {
  int rootPc = scaleDegreeToMidiRoot(degree, 0) % 12;
  if (quality.equals("minor") || quality.equals("minor6") || quality.equals("diminished")) {
    return new int[] {rootPc, (rootPc + 2) % 12, (rootPc + 3) % 12, (rootPc + 5) % 12, (rootPc + 7) % 12, (rootPc + 8) % 12, (rootPc + 10) % 12};
  }
  return new int[] {rootPc, (rootPc + 2) % 12, (rootPc + 4) % 12, (rootPc + 5) % 12, (rootPc + 7) % 12, (rootPc + 9) % 12, (rootPc + 11) % 12};
}

long applySwingTick(long relTick, int swingTicks) {
  if (swingTicks == 0) return relTick;
  long slot = relTick / chordSlotTicks;
  return (slot % 2) == 1 ? Math.max(0L, relTick + swingTicks) : relTick;
}

void addProgramChange(Track tr, int channel, int program, long tick) {
  try {
    ShortMessage pc = new ShortMessage();
    pc.setMessage(ShortMessage.PROGRAM_CHANGE, channel, constrain(program, 0, 127), 0);
    tr.add(new MidiEvent(pc, tick));
  } catch (Exception e) {
    println("program change failed: " + e.getMessage());
  }
}

void addMidiNote(Track tr, int channel, int note, int velocity, long startTick, long endTick) {
  try {
    int n = constrain(note, 0, 127);
    int v = constrain(velocity, 1, 127);
    long offTick = Math.max(startTick + 1L, endTick);

    ShortMessage on = new ShortMessage();
    on.setMessage(ShortMessage.NOTE_ON, channel, n, v);
    tr.add(new MidiEvent(on, startTick));

    ShortMessage off = new ShortMessage();
    off.setMessage(ShortMessage.NOTE_OFF, channel, n, 0);
    tr.add(new MidiEvent(off, offTick));
  } catch (Exception e) {
    println("note write failed: " + e.getMessage());
  }
}

void addPercHit(Track tr, int note, int velocity, long tick) {
  long off = tick + max(10, chordSlotTicks / 8);
  addMidiNote(tr, 9, note, velocity, tick, off);
}

