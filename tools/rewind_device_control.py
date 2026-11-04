"""Bounded Rewind-only automation using the user's existing ipadwifi USB SSH.

No new SSH keys, daemon, listening port or system touch injection. The existing launcher
wakes Rewind; a one-shot file request and Darwin notification arm its exercise.
"""
import argparse
import json
import os
from pathlib import Path
import sys
import time
import uuid

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT.parent / "ipadwifi"))
import ipad_ssh
import retroarch_usb as usb
usb.APP_ID = b"org.local.ministreamlab"


def status():
    output = ipad_ssh.run("ps -A", timeout=15).stdout.decode()
    return [line for line in output.splitlines()
            if line.rstrip().endswith("/MiniStreamLab")]


def launch():
    # Existing uiopen silently ignores this launch on the old OS. The local
    # Rewind-only helper checks lock state and never bypasses a passcode.
    result = ipad_ssh.run("cd /var/mobile && su mobile -c '/var/mobile/Media/RewindLab/rewind-launch launch'", timeout=15,
                         check=False)
    if result.returncode:
        raise RuntimeError("Rewind launch failed: " + result.stderr.decode())


def exercise(action, build, destination, playback_case=None, caption_check=False, caption_choice=None, prepare_check=False, prepare_dwell=None, trace_transport=False, caption_probe=None, legacy_font=None):
    destination.mkdir(parents=True, exist_ok=True)
    os.chmod(destination, 0o700)
    request = {"protocol": 1, "expected_build": build,
               "expires": time.time() + 240, "run": str(uuid.uuid4()),
               "action": action}
    if trace_transport and (action != "playback-title" or build < 281):
        raise ValueError("Transport capture requires the admitted281+ title diagnostic")
    trace_count, trace_finished = 0, False
    if playback_case is not None:
        if action != "playback-title": raise ValueError("Case requires playback-title")
        request["playback_case"] = playback_case
    if caption_check:
        if action != "playback-title" or playback_case is None: raise ValueError("Caption check requires a real playback case")
        request["caption_check"] = True
    if prepare_check:
        if action != "playback-title" or playback_case not in ("tenzing", "just-play-dead", "matrix", "back-to-future") or caption_check:
            raise ValueError("Preparation check requires one admitted movie, without caption check")
        request["prepare_check"] = True
    if prepare_dwell is not None:
        if not prepare_check or prepare_dwell not in (0, 12):
            raise ValueError("Preparation dwell requires the owned preparation check and0or12 seconds")
        request["prepare_dwell"] = prepare_dwell
    if caption_choice is not None:
        admitted = {("back-to-future", "back-to-future-sidecar"), ("severance", "severance-embedded")}
        if not caption_check or (playback_case, caption_choice) not in admitted:
            raise ValueError("Manual caption check requires an admitted real subtitle track")
        request["caption_choice"] = caption_choice
    if caption_probe is not None:
        if build < 283 or caption_probe != "severance-2648" or not caption_check or (playback_case, caption_choice) != ("severance", "severance-embedded") or action != "playback-title":
            raise ValueError("Known-cue capture requires the admitted283+ Severance caption diagnostic")
        request["caption_probe"] = caption_probe
    if legacy_font is not None:
        allowed_fonts = ("default", "Arial", "HelveticaNeue") if build >= 289 else ("default", "Arial")
        allowed_actions = ("audio-mkv", "subtitles-mkv", "subtitles-font-mkv") if build >= 290 else ("audio-mkv", "subtitles-mkv")
        if build < 287 or action not in allowed_actions or legacy_font not in allowed_fonts:
            raise ValueError("Font experiment requires admitted bundled MKV diagnostic; exact HelveticaNeue requires289+")
        request["legacy_font"] = legacy_font
    local = destination / (action + "-request.json")
    local.write_text(json.dumps(request))
    os.chmod(local, 0o600)
    with usb.Documents() as documents:
        documents.put_new(local, "/Documents/rewind-device-exercise.request")
    launch()
    admission_check = time.monotonic() + 10
    admission_rewoken = False
    deadline, last_update = time.monotonic() + (35 if action == "close" else 355 if action in ("playback-long", "playback-reconnect", "playback-title", "playback-controlled-mkv", "playback-lifecycle") else 205), 0
    while time.monotonic() < deadline:
        with usb.Documents() as documents:
            try:
                data = documents.read("/Documents/RewindDiagnostics/device-exercise.json")
                result = json.loads(data)
            except FileNotFoundError:
                result = {}
            if trace_transport and not trace_finished:
                try:
                    report = json.loads(documents.read("/Documents/session-report.json"))
                except (FileNotFoundError, json.JSONDecodeError):
                    report = {}
                metrics = report.get("playback_metrics", {})
                if report.get("device_exercise_admission", {}).get("run") == request["run"] and str(metrics.get("context", {}).get("build")) == str(build):
                    discovery = report.get("discovery", {})
                    fields = ("infoHash", "fileIdx", "elapsed", "timing", "peers", "seeders_hint", "seeds_connected", "payload_bytes", "measured_bytes_per_second", "rate_sample_seconds", "probe_outstanding_bytes", "opening_missing_bytes", "verified_prefix_bytes", "local_checking", "selectable", "transport")
                    record = {"run": request["run"], "session_id": metrics.get("session_id"), "elapsed": metrics.get("elapsed_seconds"), "host_monotonic": time.monotonic(), "stages": metrics.get("startup_stages_seconds", {}), "first_advancing": metrics.get("first_advancing_playback_seconds"), "focus": discovery.get("focus"), "probes": [{k: s[k] for k in fields if k in s} for s in discovery.get("candidates", [])[:3]], "selected_transport": report.get("torrent", {}).get("transport"), "source_outcomes_count": len(metrics.get("source_outcomes", []))}
                    trace_file = destination / "transport-trace.jsonl"
                    with trace_file.open("a") as trace:
                        trace.write(json.dumps(record) + "\n")
                    os.chmod(trace_file, 0o600)
                    trace_count += 1
                    advancing = metrics.get("first_advancing_playback_seconds", -1)
                    trace_finished = trace_count >= 180 or (advancing >= 0 and metrics.get("elapsed_seconds", 0) >= advancing + 10)
            if result.get("run") == request["run"]:
                target = destination / (action + "-result.json")
                target.write_bytes(data)
                os.chmod(target, 0o600)
                if action in ("loading-ui", "profiles-details", "cast-scroll", "discovery", "detail-pages", "detail-pages-landscape", "availability", "reminders") and result["status"] == "complete":
                    names = ("device-exercise-availability-coming.png", "device-exercise-availability-coming-lower.png", "device-exercise-reminder-menu.png") if action == "reminders" else tuple("device-exercise-detail-"+n+".png" for n in ["oak","director","director-page","return","studio","reuse","interstellar","series","episodes","related-movie","related-series","artwork-placeholder","artwork-repaired"]) if action in ("detail-pages", "detail-pages-landscape") else tuple("device-exercise-availability-"+n+".png" for n in ["home","home-lower","coming","coming-lower","waiting","following","detail","return","home-return"]) if action == "availability" else tuple("device-exercise-discovery-"+n+".png" for n in ["people","remote","person","person-page","person-return","studios","studio","studio-page","studio-return","moods","films","shows"]) if action == "discovery" else ("device-exercise-cast-first.png", "device-exercise-cast-last.png", "device-exercise-cast-person.png", "device-exercise-cast-return.png") if action == "cast-scroll" else ("device-exercise-home.png", "device-exercise-loading.png") if action == "loading-ui" else (
                        "device-exercise-profiles.png", "device-exercise-kids-home.png", "device-exercise-regular-home.png",
                        "device-exercise-kids-detail.png", "device-exercise-regular-detail.png")
                    for name in names:
                        capture = destination / name
                        capture.write_bytes(documents.read("/Documents/RewindDiagnostics/" + name))
                        os.chmod(capture, 0o600)
                if action == "related-quality" and result["status"] == "complete":
                    for label in ["interstellar", "severance", "dory", "matrix"]:
                        name = "device-exercise-detail-related-"+label+".png"
                        (destination / name).write_bytes(documents.read("/Documents/RewindDiagnostics/"+name))
                if action == "artwork-states":
                    for step in result.get("steps", []):
                        if not step["kind"].startswith("artstate-audit-"): continue
                        name="device-exercise-"+step["kind"]+".png"
                        try: data=documents.read("/Documents/RewindDiagnostics/"+name)
                        except FileNotFoundError: continue
                        f=destination/name;f.write_bytes(data);os.chmod(f,0o600)
                if action == "entity-art":
                    for step in result.get("steps", []):
                        if not step["kind"].startswith("entityart-audit-"): continue
                        name="device-exercise-"+step["kind"]+".png"
                        try: capture=documents.read("/Documents/RewindDiagnostics/"+name)
                        except FileNotFoundError: continue
                        f=destination/name;f.write_bytes(capture);os.chmod(f,0o600)
                if action == "entity-art" and any(step["kind"] == "entityart-company-proof" for step in result["steps"]):
                    name="device-exercise-entityart-banijay.png"
                    try: capture=documents.read("/Documents/RewindDiagnostics/"+name)
                    except FileNotFoundError: pass
                    else:
                        f=destination/name;f.write_bytes(capture);os.chmod(f,0o600)
                if action == "entity-network":
                    for suffix in ("fast", "failure", "footer", "empty", "studio"):
                        name="device-exercise-entitynet-audit-"+suffix+".png"
                        try: capture=documents.read("/Documents/RewindDiagnostics/"+name)
                        except FileNotFoundError: continue
                        f=destination/name;f.write_bytes(capture);os.chmod(f,0o600)
                if action == "search-network":
                    for suffix in ("fast", "offline", "header"):
                        name="device-exercise-searchnet-audit-"+suffix+".png"
                        try: capture=documents.read("/Documents/RewindDiagnostics/"+name)
                        except FileNotFoundError: continue
                        f=destination/name;f.write_bytes(capture);os.chmod(f,0o600)
                if action == "library-browse":
                    for step in result.get("steps", []):
                        if not step["kind"].startswith("library-audit-"): continue
                        name="device-exercise-"+step["kind"]+".png"
                        try: data=documents.read("/Documents/RewindDiagnostics/"+name)
                        except FileNotFoundError: continue
                        target=destination/name;target.write_bytes(data);os.chmod(target,0o600)
                if action.startswith("notification-"):
                    for step in result["steps"]:
                        if not step["kind"].startswith("notification-audit-"): continue
                        name="device-exercise-"+step["kind"]+".png"
                        try: data=documents.read("/Documents/RewindDiagnostics/"+name)
                        except FileNotFoundError: continue
                        f=destination/name;f.write_bytes(data);os.chmod(f,0o600)
                if action == "presentation":
                    for step in result["steps"]:
                        if not step["kind"].startswith("presentation-audit-"): continue
                        name="device-exercise-"+step["kind"]+".png"
                        try: capture=documents.read("/Documents/RewindDiagnostics/"+name)
                        except FileNotFoundError: continue
                        f=destination/name;f.write_bytes(capture);os.chmod(f,0o600)
                if action in ("audio-name-native", "audio-name-mkv", "audio-native", "audio-mkv", "audio-save-native", "audio-open-native", "audio-save-mkv", "audio-open-mkv"):
                    for step in result.get("steps", []):
                        if not step["kind"].startswith("audio-audit-"): continue
                        name="device-exercise-"+action+"-"+step["kind"].removeprefix("audio-audit-")+".png"
                        try: data=documents.read("/Documents/RewindDiagnostics/"+name)
                        except FileNotFoundError: continue
                        f=destination/name;f.write_bytes(data);os.chmod(f,0o600)
                if action in ("subtitles-native", "subtitles-mkv"):
                    # Retain completed captures on failure too, to diagnose the
                    # actual player rather than rerunning blindly.
                    for step in result["steps"]:
                        if not step["kind"].startswith("subtitle-audit-"): continue
                        name="device-exercise-"+action+"-"+step["kind"].removeprefix("subtitle-audit-")+".png"
                        try: data=documents.read("/Documents/RewindDiagnostics/"+name)
                        except FileNotFoundError: continue
                        target_capture=destination/name;target_capture.write_bytes(data);os.chmod(target_capture,0o600)
                if action in ("feed-lists", "feed-entity", "feed-retry", "feed-discovery"):
                    for suffix in (("page-studio", "return-studio", "query", "mood-movie", "return-mood", "mood-series") if action == "feed-discovery" else ("page-entity", "return-entity") if action == "feed-entity" else ("error", "end") if action == "feed-retry" else ("page-movies", "return-movies", "page-series", "return-series", "page-entity", "return-entity", "error", "end")):
                        name="device-exercise-feed-"+suffix+".png"
                        try: capture=documents.read("/Documents/RewindDiagnostics/"+name)
                        except FileNotFoundError: continue
                        f=destination/name;f.write_bytes(capture);os.chmod(f,0o600)
                if action == "download-controls":
                    for step in result["steps"]:
                        if not step["kind"].startswith("download-audit-"): continue
                        name="device-exercise-"+step["kind"]+".png"
                        try: capture=documents.read("/Documents/RewindDiagnostics/"+name)
                        except FileNotFoundError: continue
                        f=destination/name;f.write_bytes(capture);os.chmod(f,0o600)
                if action.startswith("preferences-"):
                    for step in result["steps"]:
                        if step["kind"].startswith("prefs-revision-audit:"):
                            name="device-exercise-"+action+"-"+step["kind"].replace(":", "-")+".png"
                        elif step["kind"].startswith("prefs-audit-"):
                            name="device-exercise-"+action+"-"+step["kind"]+".png"
                        elif step["kind"].startswith("prefs-link-frame:"):
                            name="device-exercise-subtitle-frame-"+step["kind"].split(":",1)[1]+".png"
                        else: continue
                        try: capture=documents.read("/Documents/RewindDiagnostics/"+name)
                        except FileNotFoundError: continue
                        f=destination/name;f.write_bytes(capture);os.chmod(f,0o600)
                if action == "episode-progress":
                    for suffix in ("home-resume", "home-next", "resume", "next", "season", "unwatched"):
                        name="device-exercise-episodes-"+suffix+".png"
                        try: capture=documents.read("/Documents/RewindDiagnostics/"+name)
                        except FileNotFoundError: continue
                        f=destination/name;f.write_bytes(capture);os.chmod(f,0o600)
                if action in ("subtitles-mkv", "subtitles-font-mkv"):
                    suffixes = tuple("font-"+str(i) for i in range(1,6)) if action == "subtitles-font-mkv" else ("embedded-settled", "embedded-french-settled", "embedded-off-settled", "embedded-return", "embedded-delay")
                    for suffix in suffixes:
                        name="device-exercise-subtitle-frame-"+suffix+".png"
                        try: capture=documents.read("/Documents/RewindDiagnostics/"+name)
                        except FileNotFoundError: continue
                        f=destination/name;f.write_bytes(capture);os.chmod(f,0o600)
                if action == "preferences-open-link-mkv":
                    for index in range(3):
                        name=f"device-exercise-presentation-52-{index}.png"
                        try: capture=documents.read("/Documents/RewindDiagnostics/"+name)
                        except FileNotFoundError: continue
                        f=destination/name;f.write_bytes(capture);os.chmod(f,0o600)
                if action in ("subtitles-layout-native", "subtitles-layout-mkv", "subtitles-layout-native-landscape"):
                    for step in result.get("steps", []):
                        if not step["kind"].startswith("subtitle-layout-audit:"): continue
                        name="device-exercise-"+step["kind"].replace(":", "-")+".png"
                        try: capture=documents.read("/Documents/RewindDiagnostics/"+name)
                        except FileNotFoundError: continue
                        target_capture=destination/name;target_capture.write_bytes(capture);os.chmod(target_capture,0o600)
                if action == "subtitles-text":
                    for name in ["unicode","encoding","cyrillic","central","overlap","older","off"]:
                        filename="device-exercise-subtitles-text-"+name+".png"
                        try:(destination/filename).write_bytes(documents.read("/Documents/RewindDiagnostics/"+filename))
                        except FileNotFoundError:pass
                if action == "subtitles-http":
                    for suffix in ("srt", "vtt", "headers", "replacement", "off", "https"):
                        name="device-exercise-http-"+suffix+".png"
                        try: capture=documents.read("/Documents/RewindDiagnostics/"+name)
                        except FileNotFoundError: continue
                        target_capture=destination/name;target_capture.write_bytes(capture);os.chmod(target_capture,0o600)
                print(json.dumps({"status": result["status"], "steps": len(result["steps"]),
                                  "seconds": result["seconds"], "saved": str(target)}), flush=True)
                return result
        if time.monotonic() - last_update > 15:
            if action != "close" and not status():
                failure = destination / (action + "-failure.json")
                failure.write_text(json.dumps({"run": request["run"], "build": build,
                                               "status": "app_exited_before_receipt"}))
                os.chmod(failure, 0o600)
                raise RuntimeError("Rewind exited before its exercise receipt; inspect the crash report before retrying")
            if not admission_rewoken and time.monotonic() >= admission_check:
                with usb.Documents() as documents:
                    try:
                        pending = json.loads(documents.read("/Documents/rewind-device-exercise.request"))
                    except FileNotFoundError:
                        pending = None
                if pending == request and request["expires"] > time.time():
                    # The exact request is still unconsumed: wake it once,
                    # without replacing it or starting a second exercise.
                    admission_rewoken = True
                    wake = destination / (action + "-admission-wake.json")
                    wake.write_text(json.dumps({"run": request["run"], "build": build,
                                                "reason": "matching_request_still_unconsumed"}))
                    os.chmod(wake, 0o600)
                    launch()
            print("Waiting for the iPad's bounded " + action + " exercise…", flush=True)
            last_update = time.monotonic()
        time.sleep(2)
    raise TimeoutError("No matching exercise receipt; inspect app state before retrying")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["subtitles-frames-mkv", "subtitles-font-mkv", "font-lookup", "playback-lifecycle",'preferences-save-revision-native', 'preferences-open-revision-changed-native', 'preferences-open-revision-again-native', 'preferences-open-revision-restored-native', 'preferences-open-revision-profiles-native', 'preferences-save-revision-mkv', 'preferences-open-revision-changed-mkv', 'preferences-open-revision-again-mkv', 'preferences-open-revision-restored-mkv', 'preferences-open-revision-profiles-mkv', "playback-controlled-mkv", "audio-name-native", "audio-name-mkv", "subtitles-timing-native", "subtitles-timing-mkv", "subtitles-layout-native-landscape", "subtitles-layout-native", "subtitles-layout-mkv", "audio-save-native", "audio-open-native", "audio-save-mkv", "audio-open-mkv", "preferences-save-link-native", "preferences-open-link-native", "preferences-save-link-mkv", "preferences-open-link-mkv", "home-categories-landscape", "home-world", "home-world-kids", "availability-layout", "title-artwork", "home-theme-series", "home-theme-series-kids", "availability-refresh", "home-categories", "home-anchors", "home-rails", "home-rails-kids", "home-series", "home-series-kids", "kids-series", "kids-series-reopen", "kids-density", "profile-cinematic", "profile-intro", "kids-surfaces", "artwork-states", "related-quality", "entity-art", "entity-network", "search-network", "library-browse", "notification-routing", "notification-schedule", "notification-open-probe", "presentation", "feed-discovery", "featured-ready", "status", "launch", "home-scroll", "loading-ui", "profiles-details", "cast-scroll", "discovery", "detail-pages", "detail-pages-landscape", "availability", "reminders", "playback", "playback-long", "playback-reconnect", "playback-title", "audio-native", "audio-mkv", "subtitles-native", "subtitles-mkv", "subtitles-http", "subtitles-text", "resume-save-native", "resume-open-native", "resume-save-mkv", "resume-open-mkv", "resume-save-torrent", "resume-open-torrent", "resume-cleanup", "download-controls", "download-playback", "kids-boundaries", "kids-playback", "preferences-save-native", "preferences-open-native", "preferences-save-mkv", "preferences-open-mkv", "episode-progress", "episode-handoff", "feed-lists", "feed-entity", "feed-retry", "close"])
    parser.add_argument("--build", type=int, default=300)
    parser.add_argument("--output", type=Path, default=ROOT / "diagnostics/rewind-0.221-device-exercise")
    parser.add_argument("--playback-case", choices=["tenzing", "just-play-dead", "matrix", "back-to-future", "two-half-early", "two-half-late", "breaking-bad", "severance"])
    args = parser.parse_args()
    if args.action == "status":
        print(json.dumps({"running": bool(status())}))
    elif args.action == "launch":
        launch()
    else:
        result = exercise(args.action, args.build, args.output, args.playback_case)
        if result["status"] not in ("complete", "closed_after_state_flush"):
            sys.exit(1)
