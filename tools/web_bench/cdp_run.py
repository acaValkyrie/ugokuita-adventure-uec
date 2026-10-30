import argparse
import asyncio
import base64
import json
import math
import re
import subprocess
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

import websockets


class CDP:
    def __init__(self, ws):
        self.ws, self.next_id, self.pending, self.loads = ws, 0, {}, []
        self.reader = asyncio.create_task(self.receive())

    async def receive(self):
        try:
            async for raw in self.ws:
                message = json.loads(raw)
                future = self.pending.get(message.get("id"))
                if future is not None and not future.done():
                    future.set_result(message)
                if message.get("method") == "Page.loadEventFired":
                    for waiter in self.loads:
                        if not waiter.done():
                            waiter.set_result(None)
        finally:
            for future in self.pending.values():
                if not future.done():
                    future.set_exception(ConnectionError("CDP connection closed"))

    async def send(self, method, params=None):
        self.next_id += 1
        command_id = self.next_id
        future = asyncio.get_running_loop().create_future()
        self.pending[command_id] = future
        try:
            await self.ws.send(json.dumps({"id": command_id, "method": method,
                                           "params": params or {}}))
            message = await future
            if "error" in message:
                raise RuntimeError(json.dumps(message["error"], ensure_ascii=False))
            return message.get("result", {})
        finally:
            self.pending.pop(command_id, None)


INSTRUMENT = r"""(() => {
 if (location.pathname.includes('__cdp_probe')) return;
 const log = window.__log = {nav0: performance.timeOrigin, long: [], buckets: [], console: [], bright: []};
 try {
   log.gl = {};
   log.glSlow = [];
   log.glAllPrograms = [];
   log.glSlowPrograms = [];
   log.glPrograms = 0;
   log.glShaders = 0;
   log.glShaderSourceTotal = 0;
   log.glShaderSourceMax = 0;
   log.glTimeline = [];
   const proto = typeof WebGL2RenderingContext === 'undefined' ? null : WebGL2RenderingContext.prototype;
   const sources = new WeakMap(), shaderTypes = new WeakMap(), attachedShaders = new WeakMap();
   const checkedPrograms = new WeakSet(), usedPrograms = new WeakSet(), seconds = new Map();
   const defines = source => Array.from(source.matchAll(/^\s*#define\s+(\w+)/gm), match => match[1]);
   if (proto) {
     const shaderSource = proto.shaderSource;
     proto.shaderSource = function() {
       try { sources.set(arguments[0], String(arguments[1])); } catch (_) {}
       try { return shaderSource.apply(this, arguments); } catch (_) {}
     };
     const createShader = proto.createShader;
     proto.createShader = function(type) {
       const shader = createShader.apply(this, arguments);
       try { if (shader) shaderTypes.set(shader, type); } catch (_) {}
       return shader;
     };
     const attachShader = proto.attachShader;
     proto.attachShader = function(program, shader) {
       const result = attachShader.apply(this, arguments);
       try {
         let shaders = attachedShaders.get(program);
         if (!shaders) { shaders = new Set(); attachedShaders.set(program, shaders); }
         shaders.add(shader);
       } catch (_) {}
       return result;
     };
     for (const name of ['compileShader','linkProgram','getShaderParameter','getProgramParameter',
                         'getShaderInfoLog','getProgramInfoLog','useProgram','getUniformLocation']) {
       const original = proto[name];
       log.gl[name] = {count: 0, ms: 0};
       proto[name] = function() {
         let start, measured = true, firstLinkStatus = false;
         try {
           if (name === 'getProgramParameter' && arguments[1] === 35714 &&
               arguments[0] && !checkedPrograms.has(arguments[0])) {
             checkedPrograms.add(arguments[0]);
             firstLinkStatus = true;
           }
           if (name === 'useProgram') {
             const program = arguments[0];
             measured = program !== null && !usedPrograms.has(program);
             if (measured) usedPrograms.add(program);
           }
           if (measured) start = performance.now();
         } catch (_) { measured = false; }
         try { return original.apply(this, arguments); } catch (_) {}
         finally {
           try {
             if (measured && start !== undefined) {
               const duration = performance.now() - start, stat = log.gl[name];
               stat.count++; stat.ms += duration;
               if (firstLinkStatus || (name === 'getProgramParameter' && duration > 100)) {
                 const shaders = attachedShaders.get(arguments[0]) || [];
                 const sourceFor = type => Array.from(shaders)
                   .filter(shader => shaderTypes.get(shader) === type)
                   .map(shader => sources.get(shader) || '').join('\n');
                 const vertex = sourceFor(35633), fragment = sourceFor(35632);
                 const entry = {t: Math.round(start), ms: Math.round(duration), fdefs: defines(fragment)};
                 if (firstLinkStatus && log.glAllPrograms.length < 2000) log.glAllPrograms.push(entry);
                 if (duration > 100 && log.glSlowPrograms.length < 1000) {
                   log.glSlowPrograms.push({...entry, vlen: vertex.length, flen: fragment.length,
                     vdefs: defines(vertex), fhead: fragment.split(/\r?\n/)
                       .filter(line => line.trim() && !line.trimStart().startsWith('#define'))
                       .slice(0, 30).join('\n').slice(0, 1500)});
                 }
               }
               if (duration > 20 && log.glSlow.length < 5000)
                 log.glSlow.push([Math.round(start), name, Math.round(duration)]);
               const second = Math.floor(start / 1000);
               let bucket = seconds.get(second);
               if (!bucket) {
                 bucket = [second, 0, 0];
                 seconds.set(second, bucket);
                 log.glTimeline.push(bucket);
               }
               bucket[2] += duration;
               if (name === 'linkProgram') { log.glPrograms++; bucket[1]++; }
               if (name === 'compileShader') {
                 log.glShaders++;
                 const length = (sources.get(arguments[0]) || '').length;
                 log.glShaderSourceTotal += length;
                 log.glShaderSourceMax = Math.max(log.glShaderSourceMax, length);
               }
             }
           } catch (_) {}
         }
       };
     }
   }
 } catch (_) {}
 const record = (level, args) => {
   if (log.console.length < 3000) log.console.push([Math.round(performance.now()), level,
     args.map(x => { try { return String(x); } catch (_) { return '[unprintable]'; } }).join(' ').slice(0,4000)]);
 };
 for (const level of ['log','info','warn','error']) {
   const original = console[level];
   console[level] = function(...args) { record(level,args); return original.apply(this,args); };
 }
 window.addEventListener('error', e => record('exception',[e.message || e.error]));
 window.addEventListener('unhandledrejection', e => record('exception',[e.reason]));
 let previous = performance.now(), start = previous, count = 0, maximum = 0, sample = -250, last = null;
 const small = document.createElement('canvas'); small.width = small.height = 8;
 const ctx = small.getContext('2d', {willReadFrequently:true});
 function frame(t) {
   const d = t - previous; previous = t; count++; maximum = Math.max(maximum,d);
   if (d > 50) log.long.push([Math.round(t),Math.round(d)]);
   if (t-start >= 1000) {
     log.buckets.push([Math.round(start),count,Math.round(maximum)]);
     start=t; count=0; maximum=0;
   }
   if (t-sample >= 250) {
     sample=t;
     try {
       const canvas=document.querySelector('canvas');
       if (canvas) {
         ctx.drawImage(canvas,0,0,8,8);
         const data=ctx.getImageData(0,0,8,8).data, rgb=[0,0,0];
         for(let i=0;i<data.length;i+=4) for(let c=0;c<3;c++) rgb[c]+=data[i+c];
         for(let c=0;c<3;c++) rgb[c]/=64;
         if (!last || rgb.some((v,i)=>v!==last[i])) { log.bright.push([Math.round(t),...rgb]); last=rgb; }
       }
     } catch (_) {}
   }
   requestAnimationFrame(frame);
 }
 requestAnimationFrame(frame);
})();"""

SETTINGS = r"""(robot => new Promise((resolve,reject) => {
 const request=indexedDB.open('/userfs',21);
 request.onerror=()=>reject(request.error);
 request.onupgradeneeded=()=>{
   const db=request.result;
   if(!db.objectStoreNames.contains('FILE_DATA')) {
     db.createObjectStore('FILE_DATA').createIndex('timestamp','timestamp',{unique:false});
   }
 };
 request.onsuccess=()=>{
   const db=request.result, tx=db.transaction('FILE_DATA','readwrite'), store=tx.objectStore('FILE_DATA');
   const root='/userfs/godot/app_userdata/Ugokuita Adventure UEC', read=store.get(root+'/settings.cfg');
   let text;
   tx.oncomplete=()=>{db.close();resolve(text);};
   tx.onerror=()=>{db.close();reject(tx.error);};
   tx.onabort=()=>{db.close();reject(tx.error || new Error('IndexedDB transaction aborted'));};
   for(const path of ['/userfs/godot','/userfs/godot/app_userdata',root]) {
     const entry=store.get(path);
     entry.onsuccess=()=>{if(!entry.result) store.put({timestamp:new Date(),mode:16877},path);};
   }
   read.onsuccess=()=>{
     text=read.result ? new TextDecoder().decode(read.result.contents) : '[robot]\n\nmodel="'+robot+'"\n';
     if(read.result) {
       const lines=text.split('\n'); let inside=false, found=false, section=-1;
       for(let i=0;i<lines.length;i++) {
         if(/^\s*\[.*\]\s*\r?$/.test(lines[i])) {
           inside=/^\s*\[robot\]\s*\r?$/.test(lines[i]);
           if(inside) section=i;
         } else if(inside && /^model=/.test(lines[i])) { lines[i]='model="'+robot+'"';found=true; }
       }
       if(!found) {
         if(section>=0) lines.splice(section+1,0,'model="'+robot+'"');
         else lines.push('','[robot]','','model="'+robot+'"');
       }
       text=lines.join('\n');
     }
     store.put({timestamp:new Date(),mode:33206,contents:new Uint8Array(new TextEncoder().encode(text))},root+'/settings.cfg');
   };
 };
}))(%s)"""

SNAPSHOT = r"""JSON.stringify({log: window.__log, res: performance.getEntriesByType("resource").filter(r => /\.(pck|wasm)$/.test(r.name)).map(r => [r.name.split("/").pop(), Math.round(r.startTime), Math.round(r.responseEnd), r.transferSize, r.encodedBodySize]), vis: document.visibilityState, gpu: (() => { try { const g = document.createElement("canvas").getContext("webgl2"); const e = g.getExtension("WEBGL_debug_renderer_info"); return g.getParameter(e.UNMASKED_RENDERER_WEBGL); } catch (e) { return null; } })()})"""


def get_targets(port):
    with urllib.request.urlopen(f"http://127.0.0.1:{port}/json", timeout=1) as response:
        return json.load(response)


async def evaluate(cdp, expression):
    reply = await cdp.send("Runtime.evaluate", {"expression": expression,
                                               "awaitPromise": True, "returnByValue": True})
    if "exceptionDetails" in reply:
        raise RuntimeError(json.dumps(reply["exceptionDetails"], ensure_ascii=False))
    result = reply.get("result", {})
    return result.get("value", result.get("unserializableValue", result))


def summarize_profile(profile):
    nodes = {node["id"]: node for node in profile["nodes"]}
    parents = {child: node["id"] for node in profile["nodes"] for child in node.get("children", [])}
    names = {}
    for node_id, node in nodes.items():
        frame = node["callFrame"]
        name = frame.get("functionName") or "(anonymous)"
        if frame.get("url"):
            name += " " + urllib.parse.urlsplit(frame["url"]).path.rsplit("/", 1)[-1]
        names[node_id] = name
    samples = profile.get("samples", [])
    total_ms = (profile["endTime"] - profile["startTime"]) / 1000
    sample_ms = total_ms / len(samples) if samples else 0
    self_times, inclusive_times = {}, {}
    for node_id in samples:
        name = names[node_id]
        self_times[name] = self_times.get(name, 0) + sample_ms
        seen, visited = set(), set()
        while node_id in nodes and node_id not in visited:
            visited.add(node_id)
            seen.add(names[node_id])
            node_id = parents.get(node_id)
        for name in seen:
            inclusive_times[name] = inclusive_times.get(name, 0) + sample_ms
    return {"self": sorted(self_times.items(), key=lambda item: item[1], reverse=True),
            "inclusive": sorted(inclusive_times.items(), key=lambda item: item[1], reverse=True)}, total_ms


def summarize_gl_programs(log):
    slow = log.get("glSlowPrograms", [])
    all_programs = log.get("glAllPrograms", [])
    print(f"GL slow programs: {len(slow)}")

    def groups(programs):
        grouped = {}
        for program in programs:
            key = ",".join(sorted(program.get("fdefs", [])))
            count, milliseconds = grouped.get(key, (0, 0))
            grouped[key] = (count + 1, milliseconds + program["ms"])
        return sorted(grouped.items(), key=lambda item: item[1][1], reverse=True)

    print("GL slow program groups (count, total ms, defines):")
    for defines, (count, milliseconds) in groups(slow):
        print(f"{count}\t{milliseconds}\t{defines[:400]}")
    print("GL all program groups top 40 (count, total ms, defines):")
    for defines, (count, milliseconds) in groups(all_programs)[:40]:
        print(f"{count}\t{milliseconds}\t{defines[:300]}")
    print("GL define occurrences (define, slow programs, fast programs):")
    slow_defines = sorted({define for program in slow for define in program.get("fdefs", [])})
    fast = [program for program in all_programs if program["ms"] <= 100]
    for define in slow_defines:
        slow_count = sum(define in program.get("fdefs", []) for program in slow)
        fast_count = sum(define in program.get("fdefs", []) for program in fast)
        print(f"{define}\t{slow_count}\t{fast_count}")


async def run(args):
    actions = json.loads(Path(args.actions).read_text(encoding="utf-8")) if args.actions else []
    if not isinstance(actions, list) or any(not isinstance(a, list) or len(a) != 2
            or not isinstance(a[0], (int, float)) or a[0] < 0 or not isinstance(a[1], str) for a in actions):
        raise ValueError("actions must be a list of [nonnegative seconds, JS expression]")
    profiles = []
    for specification in args.cpu_profile:
        start, duration, name = specification.split(":", 2)
        start, duration = float(start), float(duration)
        if not math.isfinite(start) or not math.isfinite(duration) or start < 0 or duration < 0 or not name:
            raise ValueError("cpu profiles must be START:DURATION:NAME with finite nonnegative seconds and a name")
        profiles.append((start, duration, name))
    ordered = sorted(profiles)
    if any(start < previous_start + previous_duration
            for (previous_start, previous_duration, _), (start, _, _) in zip(ordered, ordered[1:])):
        raise ValueError("cpu profile time ranges must not overlap")
    if len({name for _, _, name in profiles}) != len(profiles):
        raise ValueError("cpu profile names must be unique")
    Path(args.profile_dir).mkdir(parents=True, exist_ok=True)
    flags = [args.chrome, f"--remote-debugging-port={args.port}", f"--user-data-dir={Path(args.profile_dir).resolve()}",
             "--no-first-run", "--no-default-browser-check", "--window-size=1920,1080", "--window-position=0,0",
             "--disable-background-timer-throttling", "--disable-renderer-backgrounding", "--disable-backgrounding-occluded-windows"]
    if args.cold:
        flags.append("--disable-gpu-shader-disk-cache")
    process = subprocess.Popen(flags + ["about:blank"])
    ws, cdp, jobs, profile_jobs, screenshot_jobs = None, None, [], [], []
    try:
        deadline = time.monotonic() + 30
        while True:
            try:
                targets = await asyncio.to_thread(get_targets, args.port)
                target = next((t for t in targets if t.get("type") == "page"), None)
                if target:
                    break
            except (OSError, ValueError):
                pass
            if time.monotonic() >= deadline:
                raise TimeoutError("Chrome page target did not appear within 30 seconds")
            await asyncio.sleep(0.1)
        ws = await websockets.connect(target["webSocketDebuggerUrl"], max_size=None)
        cdp = CDP(ws)
        await cdp.send("Page.enable")
        await cdp.send("Runtime.enable")
        settings = None
        if args.robot != "keep":
            parsed = urllib.parse.urlsplit(args.url)
            origin = urllib.parse.urlunsplit((parsed.scheme, parsed.netloc, "", "", ""))
            loaded = asyncio.get_running_loop().create_future()
            cdp.loads.append(loaded)
            try:
                await cdp.send("Page.navigate", {"url": origin + args.probe_path})
                try:
                    await asyncio.wait_for(loaded, 5)
                except asyncio.TimeoutError:
                    pass
            finally:
                cdp.loads.remove(loaded)
            settings = await evaluate(cdp, SETTINGS % json.dumps(args.robot))
        await cdp.send("Page.addScriptToEvaluateOnNewDocument", {"source": INSTRUMENT})
        if args.cpu_throttle > 1:
            await cdp.send("Emulation.setCPUThrottlingRate", {"rate": args.cpu_throttle})
        if profiles:
            await cdp.send("Profiler.enable")
            await cdp.send("Profiler.setSamplingInterval", {"interval": 200})
        cpu_profiles = {}
        profile_lock = asyncio.Lock()
        t_nav = time.monotonic()
        results = [None] * len(actions)

        async def act(index, delay, expression):
            try:
                await asyncio.sleep(max(0, t_nav + delay - time.monotonic()))
                result = await evaluate(cdp, expression)
            except asyncio.CancelledError:
                result = {"error": "recording ended before action completed"}
            except Exception as error:
                result = {"error": str(error)}
            results[index] = [delay, expression, result]

        async def profile_cpu(start, duration, name):
            await asyncio.sleep(max(0, t_nav + start - time.monotonic()))
            async with profile_lock:
                await cdp.send("Profiler.start")
                await asyncio.sleep(duration)
                profile = (await cdp.send("Profiler.stop"))["profile"]
            out = Path(args.out)
            if out.suffix == ".json":
                out = out.with_suffix("")
            profile_path = Path(str(out) + "_" + name + ".cpuprofile")
            profile_path.parent.mkdir(parents=True, exist_ok=True)
            profile_path.write_text(json.dumps(profile, ensure_ascii=False), encoding="utf-8")
            summary, total_ms = summarize_profile(profile)
            for kind, header in (("self", "cpu profile"), ("inclusive", "inclusive")):
                print(f"== {header} {name}")
                for function, milliseconds in summary[kind][:40]:
                    percent = milliseconds / total_ms * 100 if total_ms else 0
                    print(f"{milliseconds:.3f}\t{percent:.2f}%\t{function}")
            cpu_profiles[name] = {kind: values[:100] for kind, values in summary.items()}

        navigation = await cdp.send("Page.navigate", {"url": args.url})
        if navigation.get("errorText"):
            raise RuntimeError(navigation["errorText"])
        jobs = [asyncio.create_task(act(i, *action)) for i, action in enumerate(actions)]
        profile_jobs = [asyncio.create_task(profile_cpu(*profile)) for profile in profiles]
        deadline = t_nav + args.seconds
        if args.screenshot_on:
            console_index, screenshot_count = 0, 0

            async def capture_screenshot(number, message, due):
                await asyncio.sleep(max(0, due - time.monotonic()))
                screenshot = await cdp.send("Page.captureScreenshot", {"format": "png"})
                out = Path(args.out)
                slug = re.sub(r"[^A-Za-z0-9_]", "_", message)[:40]
                screenshot_path = out.with_name(f"{out.stem}_shot_{number:02d}_{slug}.png")
                screenshot_path.parent.mkdir(parents=True, exist_ok=True)
                screenshot_path.write_bytes(base64.b64decode(screenshot["data"]))
                print(f"Screenshot: {screenshot_path}")

            while True:
                entries = await evaluate(cdp, f"(window.__log?.console || []).slice({console_index})")
                console_index += len(entries)
                for entry in entries:
                    message = entry[-1]
                    if any(re.search(pattern, message) for pattern in args.screenshot_on):
                        screenshot_count += 1
                        screenshot_jobs.append(asyncio.create_task(capture_screenshot(
                            screenshot_count, message, time.monotonic() + args.screenshot_delay)))
                remaining = deadline - time.monotonic()
                if remaining <= 0:
                    break
                await asyncio.sleep(min(0.25, remaining))
        else:
            await asyncio.sleep(max(0, deadline - time.monotonic()))
        for job in jobs:
            if not job.done():
                job.cancel()
        await asyncio.gather(*jobs)
        await asyncio.gather(*profile_jobs)
        page = json.loads(await evaluate(cdp, SNAPSHOT))
        await asyncio.gather(*screenshot_jobs)
        output = {"args": vars(args), "settings": settings, "actions": results, "page": page,
                  "cpu_profiles": cpu_profiles}
        Path(args.out).parent.mkdir(parents=True, exist_ok=True)
        Path(args.out).write_text(json.dumps(output, ensure_ascii=False, indent=1), encoding="utf-8")
        log = page.get("log") or {}
        long = log.get("long", [])
        print(f"Long frames: {len(long)}; top 10: {sorted(long, key=lambda x: x[1], reverse=True)[:10]}")
        print("Buckets:", json.dumps(log.get("buckets", []), separators=(",", ":")))
        print("GL totals:")
        for name, stat in sorted(log.get("gl", {}).items(), key=lambda item: item[1]["ms"], reverse=True):
            print(f"{name} {stat['count']} {stat['ms']:.1f}")
        print(f"GL programs: {log.get('glPrograms', 0)} shaders: {log.get('glShaders', 0)} "
              f"src total: {log.get('glShaderSourceTotal', 0)} max: {log.get('glShaderSourceMax', 0)}")
        print("GL timeline:", json.dumps([entry for entry in log.get("glTimeline", [])
                                         if entry[2] > 50], separators=(",", ":")))
        summarize_gl_programs(log)
        for line in log.get("console", []):
            if "[probe]" in line[2]:
                print(*line)
    finally:
        for job in jobs + profile_jobs + screenshot_jobs:
            if not job.done():
                job.cancel()
        if jobs or profile_jobs or screenshot_jobs:
            await asyncio.gather(*jobs, *profile_jobs, *screenshot_jobs, return_exceptions=True)
        if cdp:
            try:
                await asyncio.wait_for(cdp.send("Browser.close"), 3)
            except Exception:
                pass
        if ws:
            await ws.close()
        if cdp:
            await asyncio.gather(cdp.reader, return_exceptions=True)
        try:
            await asyncio.to_thread(process.wait, timeout=10)
        except subprocess.TimeoutExpired:
            process.kill()
            await asyncio.to_thread(process.wait)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--url", required=True)
    parser.add_argument("--profile-dir", required=True)
    parser.add_argument("--cold", action="store_true")
    parser.add_argument("--robot", choices=("keep", "neo", "classic"), default="keep")
    parser.add_argument("--seconds", type=float, default=60)
    parser.add_argument("--screenshot-on", action="append", default=[])
    parser.add_argument("--screenshot-delay", type=float, default=0.5)
    parser.add_argument("--out", required=True)
    parser.add_argument("--port", type=int, default=9333)
    parser.add_argument("--chrome", default=r"C:\Program Files\Google\Chrome\Application\chrome.exe")
    parser.add_argument("--cpu-throttle", type=float, default=1)
    parser.add_argument("--actions")
    parser.add_argument("--cpu-profile", nargs="*", default=[])
    parser.add_argument("--probe-path", default="/__cdp_probe_404")
    args = parser.parse_args()
    if args.seconds < 0:
        parser.error("--seconds must be nonnegative")
    asyncio.run(run(args))
