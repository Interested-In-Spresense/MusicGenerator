/*
 * File: AutoMerody_MidiPlayer.pde
 * Description: Generates and plays transformed MIDI songs from A/B/C motifs.
 * Author: Intersted_in_Spresense
 * License: MIT
 */

import java.io.File;
import java.util.ArrayList;
import java.util.HashMap;
import javax.sound.midi.MidiSystem;
import javax.sound.midi.Sequence;

HashMap<String, Sequence> baseMidiTable = new HashMap<String, Sequence>();
String generationStatus = "GEN: idle";
String currentAabcbSummary = "A: -  B: -  C: -  B: -";
String currentMeterBpmSummary = "meter=-  bpm=-";
String currentChordChoiceSummary = "mood=-  profile=-  A=-  B=-  C=-";

ArrayList<GeneratedSong> playbackQueue = new ArrayList<GeneratedSong>();

String formatAabcbSummary(String[] baseFiles) {
  if (baseFiles == null || baseFiles.length < 5) {
    return "A: -  B: -  C: -  B: -";
  }
  return "A=" + baseFiles[0] + "  B=" + baseFiles[2] + "  C=" + baseFiles[3] + "  B=" + baseFiles[4];
}

void updateSongDisplayAndLog(GeneratedSong song, String label) {
  if (song == null) {
    return;
  }

  String summary = formatAabcbSummary(song.baseFiles);
  String chordProfile = song.progressionProfile != null ? song.progressionProfile : "A" + song.progVarAForSong + "/B" + song.progVarBForSong + "/C" + song.progVarCForSong;
  String aOrder = song.progressionAForSong != null ? java.util.Arrays.toString(song.progressionAForSong) : "[]";
  String bOrder = song.progressionBForSong != null ? java.util.Arrays.toString(song.progressionBForSong) : "[]";
  String cOrder = song.progressionCForSong != null ? java.util.Arrays.toString(song.progressionCForSong) : "[]";

  currentAabcbSummary = summary;
  currentMeterBpmSummary = "meter=" + (song.meterIndexForSong >= 0 ? meterOptions[song.meterIndexForSong] : "?") +
    "  bpm=" + (song.bpmIndexForSong >= 0 ? bpmOptions[song.bpmIndexForSong] : "?");
  currentChordChoiceSummary = "mood=" + (song.chordMood != null ? song.chordMood : "?") +
    "  profile=" + chordProfile +
    "  A=" + aOrder +
    "  B=" + bOrder +
    "  C=" + cOrder;

  println("[" + label + "] " + summary +
    "  meter=" + (song.meterIndexForSong >= 0 ? meterOptions[song.meterIndexForSong] : "?") +
    "  bpm=" + (song.bpmIndexForSong >= 0 ? bpmOptions[song.bpmIndexForSong] : "?") +
    "  mood=" + (song.chordMood != null ? song.chordMood : "?") +
    "  profile=" + chordProfile +
    "  A=" + aOrder +
    "  B=" + bOrder +
    "  C=" + cOrder);
}

void announceQueuedSong(GeneratedSong song) {
  updateSongDisplayAndLog(song, "QUEUE");
}
int playbackQueueCapacity = 3;

int chordSlotTicks = 240;
int slotsPerBar = 8;
int phraseBars = 2;
int phraseSlots = 16;
int phraseTicks = 3840;

String[] meterOptions = {"2/4", "3/4", "4/4", "6/8", "12/8", "5/4", "7/8", "9/8"};
int meterIndex = 2;
int[] bpmOptions = {80, 84, 88, 92, 96, 100, 104, 108, 110, 112, 116, 120, 124, 128, 132, 136, 140, 145};
int bpmIndex = 8;
boolean autoMeterBpmOnSectionChange = true;
float autoShiftKeepProbability = 0.50;
float autoShiftBpmProbability = 0.70;

void setup() {
  size(920, 340);
  frameRate(120);
  surface.setTitle("AutoMerody_MidiPlayer");
  textFont(createFont("Yu Gothic UI", 20));

  initializeMidiPlayer();

  File midiDir = new File(sketchPath(".." + File.separator + ".."),
    "ssih-music" + File.separator + "tools" + File.separator + "auto_melody" + File.separator + "generated_midis");

  println("MIDI directory: " + midiDir.getAbsolutePath());
  if (!midiDir.exists()) {
    println("MIDI directory not found.");
  }
  baseMidiTable = loadBaseMidiTable(midiDir);

  // Headless batch mode for CLI execution.
  String autoBatch = System.getenv("MIDI_BATCH10_ON_START");
  if ("1".equals(autoBatch)) {
    generateBatchInMemory(1, 10);
    exit();
    return;
  }

  applyMeterByIndex(meterIndex);
  applyBpmByIndex(bpmIndex);
}

void draw() {
  background(18, 22, 30);
  fill(230);
  textAlign(LEFT, TOP);
  text("AutoMerody_MidiPlayer", 28, 24);

  textSize(18);
  fill(190);
  text("S: 再生開始", 28, 74);
  text("T: 再生停止", 28, 98);
  String playingLabel = getNowPlayingLabel();
  text("Now playing: " + (playingLabel.length() > 0 ? playingLabel : "(none)"), 28, 136);
  text("Meter: " + meterOptions[meterIndex] + "  BPM: " + bpmOptions[bpmIndex], 28, 162);
  text("Queue: " + playbackQueue.size() + "/" + playbackQueueCapacity, 28, 188);
  text("AABCB: " + currentAabcbSummary, 28, 214);
  text("Choice: " + currentMeterBpmSummary, 28, 240);
  text("Chord: " + currentChordChoiceSummary, 28, 266);
  text(generationStatus, 28, 20);

  if (!isMidiPlayerReady()) {
    return;
  }

  MidiPlaybackStatus playerStatus = getMidiPlaybackStatus();
  String st = playerStatus == MidiPlaybackStatus.PLAYING ? "RUNNING" : playerStatus == MidiPlaybackStatus.TRACK_END_PENDING ? "曲の終端処理" : "STOPPED";
  text("Sequencer: " + st + "  Tick: " + getMidiPlaybackTick(), 28, 368);

  if (consumeTrackEndPending() && isContinuousPlaybackEnabled()) {
    if (playbackQueue.isEmpty()) {
      queueNewSongIfNeeded();
    }
    if (!playbackQueue.isEmpty()) {
      startNextQueuedSong();
    }
  }
}

void keyPressed() {
  if (key == 's' || key == 'S') {
    setMidiPlaybackMode(MidiPlaybackMode.CONTINUOUS);
    if (isMidiPlaybackRunning()) {
      println("[QUEUE] playback already running; ignore S request while current song is still playing");
      return;
    }
    queueNewSongIfNeeded();
    startNextQueuedSong();
  } else if (key == 't' || key == 'T') {
    stopPlay();
  }
}

void queueNewSongIfNeeded() {
  if (playbackQueue == null || playbackQueue.isEmpty()) {
    GeneratedSong song = generateRhythmBaseSong(baseMidiTable, 1);
    if (song != null) {
      playbackQueue.add(song);
      announceQueuedSong(song);
    }
  }
}

void generateBatchInMemory(int count, int setsPerSong) {
  if (count <= 0) {
    return;
  }

  generationStatus = "GEN: start count=" + count + " sets=" + setsPerSong;
  println("[BATCH] start count=" + count + " sets=" + setsPerSong);

  int ok = 0;
  for (int i = 0; i < count; i++) {
    GeneratedSong song = generateRhythmBaseSong(baseMidiTable, setsPerSong);
    if (song != null && song.sequence != null) {
      ok++;
      println("[BATCH] generated " + (i + 1) + "/" + count + " -> " + song.label);
      generationStatus = "GEN: song " + (i + 1) + "/" + count + " done";
    } else {
      println("[BATCH] failed " + (i + 1) + "/" + count);
      generationStatus = "GEN: song " + (i + 1) + "/" + count + " failed";
    }
  }

  println("[BATCH] done in memory ok=" + ok + " / " + count);
  generationStatus = "GEN: done ok=" + ok + "/" + count;
}

HashMap<String, Sequence> loadBaseMidiTable(File sourceDir) {
  HashMap<String, Sequence> loaded = new HashMap<String, Sequence>();
  if (sourceDir == null || !sourceDir.isDirectory()) {
    println("Base MIDI directory not found.");
    return loaded;
  }

  String[] filenames = requiredBaseMidiFiles();
  for (int i = 0; i < filenames.length; i++) {
    File midiFile = new File(sourceDir, filenames[i]);
    if (!midiFile.isFile()) {
      println("Missing base MIDI: " + midiFile.getAbsolutePath());
      continue;
    }
    try {
      loaded.put(filenames[i], MidiSystem.getSequence(midiFile));
    } catch (Exception e) {
      println("Failed to load base MIDI: " + midiFile.getAbsolutePath() + " / " + e.getMessage());
    }
  }

  println("Loaded base MIDI files: " + loaded.size() + "/" + filenames.length);
  return loaded;
}

void applyMeterByIndex(int nextIndex) {
  int n = meterOptions.length;
  meterIndex = ((nextIndex % n) + n) % n;
  String meter = meterOptions[meterIndex];

  if (meter.equals("2/4")) {
    slotsPerBar = 4;
  } else if (meter.equals("3/4")) {
    slotsPerBar = 6;
  } else if (meter.equals("4/4")) {
    slotsPerBar = 8;
  } else if (meter.equals("6/8")) {
    slotsPerBar = 6;
  } else if (meter.equals("12/8")) {
    slotsPerBar = 12;
  } else if (meter.equals("5/4")) {
    slotsPerBar = 10;
  } else if (meter.equals("7/8")) {
    slotsPerBar = 7;
  } else {
    slotsPerBar = 9;
  }

  phraseSlots = slotsPerBar * phraseBars;
  phraseTicks = phraseSlots * chordSlotTicks;
  println("Meter: " + meter + "  slots/bar=" + slotsPerBar + "  phraseTicks=" + phraseTicks);
}

void refillPlaybackQueueIfNeeded() {
  if (playbackQueue == null) {
    playbackQueue = new ArrayList<GeneratedSong>();
  }

  while (playbackQueue.size() < playbackQueueCapacity) {
    GeneratedSong song = generateRhythmBaseSong(baseMidiTable, 1);
    if (song == null) {
      break;
    }
    playbackQueue.add(song);
    announceQueuedSong(song);
    if (song.meterIndexForSong >= 0) {
      meterIndex = song.meterIndexForSong;
      applyMeterByIndex(song.meterIndexForSong);
    }
    if (song.bpmIndexForSong >= 0) {
      bpmIndex = song.bpmIndexForSong;
      applyBpmByIndex(song.bpmIndexForSong);
    }
  }
}

void startNextQueuedSong() {
  if (isMidiPlaybackRunning()) {
    println("[QUEUE] ignore start request while a song is already playing");
    return;
  }

  if (playbackQueue == null || playbackQueue.isEmpty()) {
    queueNewSongIfNeeded();
    if (playbackQueue == null || playbackQueue.isEmpty()) {
      return;
    }
  }

  GeneratedSong song = playbackQueue.get(0);
  playbackQueue.remove(0);

  if (song != null) {
    updateSongDisplayAndLog(song, "PLAY");
  }

  playGeneratedSong(song);
  refillPlaybackQueueIfNeeded();
}

void stopPlay() {
  setMidiPlaybackMode(MidiPlaybackMode.SINGLE);
  playbackQueue.clear();

  stopMidiPlayback();

  currentAabcbSummary = "A: -  B: -  C: -  B: -";
  currentMeterBpmSummary = "meter=-  bpm=-";
  currentChordChoiceSummary = "mood=-  profile=-  A=-  B=-  C=-";
  println("[QUEUE] stop requested; queue cleared and playback reset");
}

void dispose() {
  closeMidiPlayer();
}

class SectionSpan {
  int startSlot;
  int endSlotExclusive;
  String section;

  SectionSpan(int startSlot, int endSlotExclusive, String section) {
    this.startSlot = startSlot;
    this.endSlotExclusive = endSlotExclusive;
    this.section = section;
  }
}

class MelodyTransform {
  int transpose;
  float velocityScale;
  float gateScale;
  int swingTicks;
  float dropoutRate;

  MelodyTransform(int transpose, float velocityScale, float gateScale, int swingTicks, float dropoutRate) {
    this.transpose = transpose;
    this.velocityScale = velocityScale;
    this.gateScale = gateScale;
    this.swingTicks = swingTicks;
    this.dropoutRate = dropoutRate;
  }

  String summary() {
    return "tr=" + transpose + " st=" + swingTicks + " gate=" + nf(gateScale, 1, 2) + " vel=" + nf(velocityScale, 1, 2);
  }
}

