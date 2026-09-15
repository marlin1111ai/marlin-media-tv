# Draft report for VideoLAN — paused previous-frame: demuxer reads while paused; resume clock start

**Not submitted.** Draft written in pass 1k (2026-09-14/15) for the owner to review. Nothing here has been sent to VideoLAN.

## Summary

With libvlc 4.0 (master `5dd4aebda`, as packaged by VLCKit 4.0.0-a24) on tvOS, pausing and stepping back with `vlc_player_PreviousVideoFrame` (VLCKit `gotoPreviousFrame`) steps exactly one picture per call.

Two things around it misbehave:

1. **The demuxer reads while paused.** After a previous-frame step, `next_frame_need_data` is left set by a subtitle decoder's data request that can never be met. The input keeps demuxing for the whole pause, and Play then shows the read-ahead pictures, all late. A 2-line change in `src/input/es_out.c` fixes it (patch below).
2. **Play after any frame step starts the clock at the demuxer's position, not at the picture on screen.** About 1 s of already-queued pictures are dropped. We did not change this, and explain why.

There's also one remaining gap in our patch, and one unsynchronised read in it. Both are listed at the end.

## Setup

- **Device.** Apple TV 4K (3rd gen), tvOS 26.6.
- **VLCKit.** Built from VideoLAN's `compileAndBuildVLCKit.sh` (4.0.0-a24, libvlc `5dd4aebda` + VLCKit's patches) with Xcode 27.0.
- **Output.** `samplebufferdisplay` vout, `avsamplebuffer` aout, VideoToolbox or avcodec decoding.
- **Media.** Local HTTP server (Range requests, not fast-seekable). Files: Matroska (MPEG-2 480i with AC-3 and a SubRip track; HEVC 2160p with TrueHD/DTS and PGS tracks) and MP4 (H.264, AAC, no subtitle tracks).
- **Evidence.** Log-only instrumentation lines in `src/input/{input,es_out,decoder}.c`, `src/clock/{clock,input_clock}.c`, `src/audio_output/dec.c`, `src/video_output/video_output.c`, `modules/audio_output/apple/avsamplebuffer.m`, plus the JSON tracer. Line numbers below are in the patched tree.

## 1. `next_frame_need_data` stays set while paused after a previous-frame step

**Steps.**
1. Play a file with a subtitle track selected; pause.
2. Wait ~80 s, then call previous-frame 5 times.
3. Wait 20 s, then Play.

**What happens.**
- **While paused, from the first step until Play, the demuxer runs.** In one run, 22 700 of 23 073 evaluations of the pause gate in `MainLoop` (`input.c:660–669`) allowed demuxing, with `es_out_GetBuffering=0 b_eof=0 next_frame_need_data=1`.
- **Its pace follows the clock the step anchored at the pause date** (`EsOutDecodersStopBuffering`, `i_current_date = p_sys->b_paused ? p_sys->i_pause_date : vlc_tick_now()`). It reads flat out until the stream catches up with wall time since the pause, then at 1×: PCR 33 s → 154 s during a 122 s pause, and a video fifo of 2 900 packets / 63 MB.
- **On Play** `EsOutResumeFromNextFrame` flushes every ES but video, so the read-ahead pictures play: 1 495 dropped in 20 s, and the on-screen position jumped from 00:33 to 02:39.

**Why the flag stays set.**
1. **The step's seek flushes the subtitle decoder while paused.** `vlc_input_decoder_Flush` sets `frames_countdown = 1` for `VIDEO_ES || SPU_ES` when paused (`decoder.c:2789–2793`).
2. **The subtitle decoder then asks for data.** With an empty fifo and `frames_countdown > 0` it calls `decoder_Notify(frame_next_need_data, true)` (`decoder.c:2065–2070`). `decoder_frame_next_need_data` in es_out pushes `INPUT_CONTROL_NEED_DATA_FRAME_NEXT`, and the input sets `next_frame_need_data` (`input.c:2549–2550`).
3. **The request can never be met.** While frame stepping, `EsOutSend` drops every block not for `p_next_frame_es` (`es_out.c:3164–3169`). The subtitle decoder never receives a block, so the clear in `vlc_input_decoder_DecodeWithStatus` (`decoder.c:2686–2687`) never runs.
4. **Only Play clears the flag** (`INPUT_CONTROL_SET_STATE`, `input.c:2151`).

In our trace: 12 288 notifications `need_data=1 frames_countdown=1` from the subtitle decoder, one `0 -> 1`, and no clear until Play.

**The patch** (in use on our device; 2 lines in `src/input/es_out.c`):
```diff
@@ -536,7 +536,7 @@ decoder_frame_next_need_data(vlc_input_decoder_t *decoder, bool need_data,
-    if (!p_sys->p_input)
+    if (!p_sys->p_input || (p_sys->p_next_frame_es != NULL && p_sys->p_next_frame_es != id))
         return;
@@ -1385,6 +1385,7 @@ static void EsOutFrameNext(es_out_sys_t *p_sys, bool previous)
             msg_Warn( p_sys->p_input, "No video track selected, ignoring 'frame next'" );
             return;
         }
+        input_ControlPushHelper( p_sys->p_input, INPUT_CONTROL_NEED_DATA_FRAME_NEXT, &(vlc_value_t){ .b_bool = false } );
     }
```
- **First line.** While frame stepping, only the stepped ES's request reaches the input. Paused seeks without frame stepping (`p_next_frame_es == NULL`) are unchanged, so the paused-seek subtitle fetch still works.
- **Second line.** It clears a request left standing from before frame stepping began. It's pushed as a control, before `vlc_input_decoder_FrameNext` / `FramePrevious`. That way an already-queued request is processed first, and a forward step's own request (sent after `StopFrameNextLocked` signals the fifo) is queued after it. `ControlGetReducedIndexLocked` never merges this control type.
- **Tests.** `test/src/player`: 19 of 20 pass before and after on a macOS build. `next_prev` passes; `attachments` fails in both runs because our stripped host build lacks a BMP encoder.
- **On the device.** The flag is never set while paused (`need_data=0` on every gate evaluation; reads only during each step's own rebuffer). There are 0 demux reads while paused outside the steps, and the position after Play is correct.

**Alternatives we rejected.**
- Not setting `frames_countdown` for SPU on a paused flush (`decoder.c:2791`), or requesting data only for video (`decoder.c:2065–2070`). Either would stop the subtitle for a new position being fetched after a user seek, title change or track change while paused, which is that line's stated purpose.
- Letting subtitle blocks through while stepping. The request is only met when a subtitle packet arrives, which can be minutes later.
- Gating in `input.c`. Forward stepping at the buffer edge needs the request.

## 2. Play after a frame step: the clock starts at the demuxer's position

**Steps.** Pause, previous-frame or next-frame ×5, then Play.

**What happens.** From one traced run (times from the unpause):
```
+0.4 ms  stop_frame_next cat=1 countdown=-1 pf_pts=33834001 fifo=21
+1.6 ms  input_clock reference stream=34785001 buffering=1
+5.2 ms  es_out stop_buffering … buffering_duration=1000000 update=… stream_start=34785001
+5.3 ms  set_first_pcr … ts=34785001
+9.4 ms  vout late render pts=33834001 late=955189
+10.7 ms vout drop pts=33917001 …  (21 drops, pts 33917001 … 34751001)
+23.1 ms vout late render pts=34785001 late=17866
```
1. **`EsOutResumeFromNextFrame` → `EsOutChangePosition(p_sys, video_es)`** resets the input clock (`es_out.c:1101`).
2. **The demuxer's next PCR becomes the clock reference** (`input_clock.c:276–281`). The demuxer is ~1 s (the pts-delay buffering) ahead of the picture on screen.
3. **`EsOutDecodersStopBuffering` anchors the main clock** with `vlc_clock_main_SetFirstPcr(update, i_stream_start)` (`es_out.c:1138–1141`, `1253–1254`).
4. **The video decoder is not flushed,** so its queue starts at the displayed picture. Pictures below the new start are dropped by the vout.

After back steps and after forward steps alike, about 1 s of pictures is dropped. Measured over five films in the first 60 s: 21–29 pictures after five back steps, and 26–45 after five forward steps (the 29.97 fps H.264 episodes drop the most). The position and on-screen clock then continue correctly.

**Why we left it.** The displayed PTS is known only to the video decoder (`video.pf_pts`, back steps only) and the vout (`displayed.timestamp`); es_out has no access to either.
- **Anchoring at the displayed PTS** would need a decoder → es_out path, and a vout getter for forward steps. It would also give ~1.1 s of picture with no sound: audio was flushed, and its first block after Play is at the demuxer's position (first audio PTS 34 912 ms).
- **Re-reading audio from the displayed picture** amounts to turning resume-from-frame-step into a seek.

Should `EsOutResumeFromNextFrame` resume as a seek to the displayed picture, or keep and re-anchor audio? We'd welcome guidance.

## 3. Remaining gaps

1. **The flag is set again by Play's flush.** `EsOutResumeFromNextFrame` calls `EsOutStopNextFrame` (`p_next_frame_es = NULL`) *before* `EsOutChangePosition` flushes the subtitle decoder, while es_out still counts as paused.
   - **What happens.** The flushed subtitle decoder asks for data again, and the patch lets that request through. So `next_frame_need_data` is set 0.8 ms after Play (`INPUT_CONTROL_NEED_DATA_FRAME_NEXT 0 -> 1`) and stays set until a subtitle block arrives or the next Play.
   - **The effect.** A later plain pause taken before a subtitle arrives lets the demuxer read while paused: 3 967 demux calls, PCR 98.4 → 182.4 s, over an 84 s pause.
   - **Only memory is affected.** That resume was clean (pause delay applied, 0 dropped).
2. **The unlocked read in the patch.** `decoder_frame_next_need_data` reads `p_sys->p_next_frame_es` from a decoder thread without `p_sys->lock`, and taking the lock there could deadlock against the decoder fifo lock the callback runs under.
   - **Why the value is visible in practice.** In the flush paths the write reaches that thread through the decoder fifo lock.
   - **Why it's still a gap.** It is formally a data race. An atomic pointer, or a flag written under the fifo lock, would close it.
3. **The trace's audio render events on tvOS are periodic.** The `avsamplebuffer` output reports timing only through a 1-second `addPeriodicTimeObserverForInterval` and skips time 0. So the first audio `RENDER realtime` trace event after a flush comes ≥1 s after sound starts. That makes it unsuitable for measuring audio start (it misled our first analysis).
