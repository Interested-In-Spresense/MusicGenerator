/*
 * File: MidiPlayer.pde
 * Description: Loads generated MIDI and manages sequencer playback and transitions.
 * Author: Intersted_in_Spresense
 * License: MIT
 */

import javax.sound.midi.MidiSystem;
import javax.sound.midi.Sequence;
import javax.sound.midi.Sequencer;
import javax.sound.midi.Track;
import javax.sound.midi.MidiEvent;
import javax.sound.midi.MidiMessage;
import javax.sound.midi.ShortMessage;
import javax.sound.midi.MetaMessage;

Sequencer sequencer;

enum MidiPlaybackStatus { UNAVAILABLE, READY, PLAYING, TRACK_END_PENDING, STOPPED, CLOSED }
enum MidiPlaybackMode { SINGLE, CONTINUOUS }

class MidiPlayerState {
  MidiPlaybackStatus status = MidiPlaybackStatus.UNAVAILABLE;
  MidiPlaybackMode mode = MidiPlaybackMode.CONTINUOUS;
  String currentLabel = "";
  Sequence previousSequence = null;
}

MidiPlayerState midiPlayerState = new MidiPlayerState();

void initializeMidiPlayer() {
  try {
    sequencer = MidiSystem.getSequencer();
    sequencer.open();
    midiPlayerState.status = MidiPlaybackStatus.READY;
  } catch (Exception e) {
    midiPlayerState.status = MidiPlaybackStatus.UNAVAILABLE;
    println("Failed to open sequencer: " + e.getMessage());
  }
}

boolean isMidiPlayerReady() {
  return sequencer != null && midiPlayerState.status != MidiPlaybackStatus.CLOSED;
}

boolean isMidiPlaybackRunning() {
  return getMidiPlaybackStatus() == MidiPlaybackStatus.PLAYING;
}

MidiPlaybackStatus getMidiPlaybackStatus() {
  if (sequencer == null) return MidiPlaybackStatus.UNAVAILABLE;
  if (midiPlayerState.status == MidiPlaybackStatus.PLAYING && !sequencer.isRunning()) {
    midiPlayerState.status = MidiPlaybackStatus.TRACK_END_PENDING;
  }
  return midiPlayerState.status;
}

boolean consumeTrackEndPending() {
  if (getMidiPlaybackStatus() != MidiPlaybackStatus.TRACK_END_PENDING) return false;
  midiPlayerState.status = MidiPlaybackStatus.READY;
  return true;
}

void setMidiPlaybackMode(MidiPlaybackMode mode) {
  if (mode != null) midiPlayerState.mode = mode;
}

boolean isContinuousPlaybackEnabled() {
  return midiPlayerState.mode == MidiPlaybackMode.CONTINUOUS;
}

String getNowPlayingLabel() {
  return midiPlayerState.currentLabel;
}

long getMidiPlaybackTick() {
  return sequencer == null ? 0 : sequencer.getTickPosition();
}

void stopMidiPlayback() {
  if (sequencer != null && sequencer.isRunning()) sequencer.stop();
  midiPlayerState.currentLabel = "";
  midiPlayerState.status = sequencer == null ? MidiPlaybackStatus.UNAVAILABLE : MidiPlaybackStatus.STOPPED;
}

void closeMidiPlayer() {
  if (sequencer == null) {
    midiPlayerState.status = MidiPlaybackStatus.CLOSED;
    return;
  }
  stopMidiPlayback();
  sequencer.close();
  midiPlayerState.previousSequence = null;
  midiPlayerState.status = MidiPlaybackStatus.CLOSED;
}

void applyBpmByIndex(int nextIndex) {
  int optionCount = bpmOptions.length;
  bpmIndex = ((nextIndex % optionCount) + optionCount) % optionCount;
  if (sequencer != null) {
    try {
      sequencer.setTempoInBPM((float)bpmOptions[bpmIndex]);
    } catch (Exception e) {
      println("Failed to set BPM: " + e.getMessage());
    }
  }
  println("BPM: " + bpmOptions[bpmIndex]);
}

void copySequenceIntoTrack(Sequence src, Track dst, long tickOffset, long clipStartTick, long clipEndTickExclusive, boolean includeMetaAtStart) {
  Track[] tracks = src.getTracks();
  for (int t = 0; t < tracks.length; t++) {
    Track tr = tracks[t];
    for (int i = 0; i < tr.size(); i++) {
      MidiEvent ev = tr.get(i);
      MidiMessage msg = ev.getMessage();
      if (msg instanceof MetaMessage) {
        MetaMessage mm = (MetaMessage)msg;
        if (mm.getType() == 0x2F) {
          continue;
        }
        if (includeMetaAtStart && ev.getTick() == 0) {
          MidiMessage copiedMeta = (MidiMessage)msg.clone();
          dst.add(new MidiEvent(copiedMeta, tickOffset));
          continue;
        }
      }

      long tick = ev.getTick();
      if (tick < clipStartTick || tick >= clipEndTickExclusive) {
        continue;
      }

      MidiMessage copied = (MidiMessage)msg.clone();
      dst.add(new MidiEvent(copied, (tick - clipStartTick) + tickOffset));
    }
  }
}

void startSequencePlayback(Sequence seq, String playingLabel, String seqLabel) {
  try {
    if (sequencer == null) {
      println("Sequencer is not available.");
      return;
    }
    if (sequencer.isRunning()) {
      sequencer.stop();
    }

    sequencer.setSequence(seq);
    sequencer.setTickPosition(0);
    sequencer.setTempoInBPM((float)bpmOptions[bpmIndex]);
    sequencer.start();

    midiPlayerState.status = MidiPlaybackStatus.PLAYING;
    midiPlayerState.currentLabel = playingLabel;
    println("Playing: " + midiPlayerState.currentLabel);
  } catch (Exception e) {
    println("Playback init failed: " + e.getMessage());
  }
}

ClipRange detectContentRange(Sequence seq) {
  long first = Long.MAX_VALUE;
  long last = 0;

  Track[] tracks = seq.getTracks();
  for (int t = 0; t < tracks.length; t++) {
    Track tr = tracks[t];
    for (int i = 0; i < tr.size(); i++) {
      MidiEvent ev = tr.get(i);
      MidiMessage msg = ev.getMessage();
      if (!(msg instanceof ShortMessage)) {
        continue;
      }
      ShortMessage sm = (ShortMessage)msg;
      int cmd = sm.getCommand();
      int vel = sm.getData2();
      if (cmd == ShortMessage.NOTE_ON && vel > 0) {
        first = Math.min(first, ev.getTick());
      }
      if (cmd == ShortMessage.NOTE_OFF || (cmd == ShortMessage.NOTE_ON && vel == 0)) {
        last = Math.max(last, ev.getTick());
      }
    }
  }

  if (first == Long.MAX_VALUE) {
    first = 0;
  }
  if (last <= first) {
    last = Math.max(first + chordSlotTicks, seq.getTickLength());
  }
  return new ClipRange(first, last + 1);
}

class ClipRange {
  long startTick;
  long endTickExclusive;

  ClipRange(long startTick, long endTickExclusive) {
    this.startTick = startTick;
    this.endTickExclusive = endTickExclusive;
  }
}

Sequence buildQueuedSongBridgeSequence(Sequence nextSeq) {
  if (nextSeq == null || midiPlayerState.previousSequence == null) {
    return nextSeq;
  }

  try {
    long prevLen = Math.max(1L, midiPlayerState.previousSequence.getTickLength());
    long nextLen = Math.max(1L, nextSeq.getTickLength());
    long crossfadeTicks = Math.max(phraseTicks * 2L, chordSlotTicks * 20L);
    long fadeOutStart = Math.max(0L, prevLen - crossfadeTicks);
    long nextStartTick = Math.max(0L, prevLen - (crossfadeTicks * 3L / 4L));

    Sequence combined = new Sequence(Sequence.PPQ, 480);
    Track dst = combined.createTrack();

    copySequenceIntoTrack(midiPlayerState.previousSequence, dst, 0L, 0L, fadeOutStart, true);
    copySequenceIntoTrackWithVelocityCurve(midiPlayerState.previousSequence, dst, 0L, fadeOutStart, prevLen, false, 0.82f, false);
    copySequenceIntoTrackWithVelocityCurve(nextSeq, dst, nextStartTick, 0L, nextLen, false, 0.42f, true);

    long endTick = Math.max(prevLen, nextStartTick + nextLen);
    MetaMessage eot = new MetaMessage();
    eot.setMessage(0x2F, new byte[0], 0);
    dst.add(new MidiEvent(eot, endTick));

    println("[PLAY] bridge: prevLen=" + prevLen + " crossfade=" + crossfadeTicks + " nextStart=" + nextStartTick + " fadeOutStart=" + fadeOutStart + " (note-level bridge)");
    return combined;
  } catch (Exception e) {
    println("Failed to build queued-song bridge: " + e.getMessage());
    return nextSeq;
  }
}

void copySequenceIntoTrackWithVelocityCurve(Sequence src, Track dst, long tickOffset, long clipStartTick, long clipEndTickExclusive, boolean includeMetaAtStart, float minScale, boolean fadeIn) {
  Track[] tracks = src.getTracks();
  for (int t = 0; t < tracks.length; t++) {
    Track tr = tracks[t];
    for (int i = 0; i < tr.size(); i++) {
      MidiEvent ev = tr.get(i);
      MidiMessage msg = ev.getMessage();
      long tick = ev.getTick();

      if (msg instanceof MetaMessage) {
        MetaMessage mm = (MetaMessage)msg;
        if (mm.getType() == 0x2F) {
          continue;
        }
        if (includeMetaAtStart && tick == 0) {
          dst.add(new MidiEvent((MidiMessage)msg.clone(), tickOffset));
        }
        continue;
      }

      if (!(msg instanceof ShortMessage)) {
        continue;
      }

      if (tick < clipStartTick || tick >= clipEndTickExclusive) {
        continue;
      }

      ShortMessage sm = (ShortMessage)msg;
      int cmd = sm.getCommand();
      int ch = sm.getChannel();
      int data1 = sm.getData1();
      int data2 = sm.getData2();

      if (cmd == ShortMessage.NOTE_ON && data2 > 0) {
        long span = Math.max(1L, clipEndTickExclusive - clipStartTick);
        float progress = constrain((float)(tick - clipStartTick) / span, 0.0f, 1.0f);

        float scale;
        if (fadeIn) {
          scale = 0.42f + 0.58f * progress;
        } else {
          scale = 1.00f - 0.18f * progress;
        }

        scale = max(minScale, scale);
        scale = min(1.0f, scale);

        int fadedVelocity = max(1, (int)(data2 * scale));
        try {
          ShortMessage out = new ShortMessage();
          out.setMessage(cmd, ch, data1, fadedVelocity);
          dst.add(new MidiEvent(out, tick + tickOffset));
        } catch (Exception e) {
          println("bridge note fade failed: " + e.getMessage());
        }
        continue;
      }

      try {
        ShortMessage out = new ShortMessage();
        out.setMessage(cmd, ch, data1, data2);
        dst.add(new MidiEvent(out, tick + tickOffset));
      } catch (Exception e) {
        println("bridge event copy failed: " + e.getMessage());
      }
    }
  }
}

void playGeneratedSong(GeneratedSong song) {
  if (song == null || song.sequence == null) {
    println("Generated song is empty.");
    return;
  }

  try {
    if (song.meterIndexForSong >= 0) {
      meterIndex = song.meterIndexForSong;
      applyMeterByIndex(song.meterIndexForSong);
    }
    if (song.bpmIndexForSong >= 0) {
      bpmIndex = song.bpmIndexForSong;
      applyBpmByIndex(song.bpmIndexForSong);
    }
    Sequence rawSeq = song.sequence;
    Sequence playbackSeq = buildQueuedSongBridgeSequence(rawSeq);
    midiPlayerState.previousSequence = rawSeq;

    println("[PLAY] " + song.label);
    println("[PLAY] song state: meter=" + meterOptions[meterIndex] + " bpm=" + bpmOptions[bpmIndex] + " mood=" + chordMood + " profile=" + lastProgressionProfile + " A=" + java.util.Arrays.toString(song.progressionAForSong) + " B=" + java.util.Arrays.toString(song.progressionBForSong) + " C=" + java.util.Arrays.toString(song.progressionCForSong));
    startSequencePlayback(playbackSeq, "generated:" + song.label, song.label);
  } catch (Exception e) {
    println("Failed to play generated song: " + e.getMessage());
  }
}
