const fs = require('fs'), vm = require('vm'), assert = require('assert');
const acorn = require('internal/deps/acorn/acorn/dist/acorn');
const source = fs.readFileSync(process.argv[2], 'utf8');
let checks = 0;
function check(value, message) { assert(value, message); checks++; }
function fixture(nativeQueue) {
    const events = [], handlers = {}, timers = [];
    let video = null, api = null, scan;
    const context = {Promise, queueMicrotask: nativeQueue, globalThis: undefined,
        webkit: {messageHandlers: {rewindTrailer: {postMessage: e => events.push(e)}}},
        addEventListener: (event, fn) => { handlers['window:' + event] = fn; },
        document: {getElementById: () => api, querySelector: q => q === 'video' ? video : null,
            addEventListener: (event, fn) => { handlers[event] = fn; }},
        setInterval: fn => { scan = fn; }, setTimeout: fn => { timers.push(fn); }};
    context.window = context;
    vm.runInNewContext(source, context);
    return {context, events, handlers, timers, scan: () => scan(), video: value => { video = value; }, api: value => { api = value; }};
}
(async function () {
    acorn.parse(source, {ecmaVersion: 5});check(true, 'Bridge uses iOS 9 syntax');
    const f = fixture();
    check(vm.runInContext('globalThis === window', f.context), 'globalThis identifies the page window');
    check(f.events[0].value.queueMicrotask === false && f.events[0].value.globalThis === false, 'Reports actual missing features');
    let order = [];
    f.context.queueMicrotask(() => { order.push('microtask'); f.context.queueMicrotask(() => order.push('nested')); });
    order.push('sync');check(order.join(',') === 'sync', 'Callbacks do not run synchronously');
    await Promise.resolve();await Promise.resolve();
    check(order.join(',') === 'sync,microtask,nested', 'Nested callbacks keep microtask ordering');
    let threw = false;try { f.context.queueMicrotask(1); } catch (e) { threw = e.name === 'TypeError'; }
    check(threw, 'Nonfunction callbacks fail synchronously');
    const failure = new Error('test error');f.context.queueMicrotask(() => { throw failure; });
    await Promise.resolve();await Promise.resolve();
    check(f.timers.length === 1, 'Thrown callback errors are reported as task errors');
    threw = false;try { f.timers[0](); } catch (e) { threw = e === failure; }check(threw, 'Original exception is preserved');
    const native = () => {};check(fixture(native).context.queueMicrotask === native, 'Existing native implementation is preserved');
    for (let i = 0; i < 12; i++) f.handlers['window:error']({message: 'failure ' + i, filename: 'https://www.youtube.com/embed/test', lineno: i});
    const errors = f.events.filter(e => e.event === 'script_errors').pop().value;
    check(errors.length === 8 && errors[0].message === 'failure 0', 'Bounded errors retain the first cause');
    f.handlers.DOMContentLoaded();check(f.events.some(e => e.event === 'document_loaded'), 'Document load is distinct from playback');
    let plays = 0, pauses = 0;
    const video = {paused: true, currentTime: 0, readyState: 0, videoWidth: 0, videoHeight: 0, muted: false,
        addEventListener: (e, fn) => { f.handlers['video:' + e] = fn; },
        play() { plays++; this.paused = false; }, pause() { pauses++; this.paused = true; }};
    f.video(video);f.scan();check(f.events.some(e => e.event === 'ready'), 'Readiness does not require a preloaded frame');
    f.context.RWTrailerCommand(true, true);check(plays === 1 && video.muted, 'Preview starts muted');
    video.currentTime = 1;f.handlers['video:timeupdate']();check(!f.events.some(e => e.event === 'state' && e.value === 1), 'Clock movement alone does not reveal video');
    video.readyState = 2;f.handlers['video:timeupdate']();check(!f.events.some(e => e.event === 'state' && e.value === 1), 'Audio-only clock cannot reveal a blank trailer');
    video.videoWidth = 1280;video.videoHeight = 720;f.handlers['video:timeupdate']();check(f.events.some(e => e.event === 'state' && e.value === 1), 'Decoded frame, dimensions and moving clock reveal video');
    f.context.RWTrailerCommand(false, true);check(pauses === 1, 'Offscreen pause reaches the player');
    const beforeLate = f.events.filter(e => e.event === 'state' && e.value === 1).length;
    video.paused = false;f.handlers['video:playing']();check(f.events.filter(e => e.event === 'state' && e.value === 1).length === beforeLate, 'Late media event cannot reveal a paused offscreen preview');
    const oldEnded = f.handlers['video:ended'], oldError = f.handlers['video:error'];
    const next = {...video, addEventListener: (e, fn) => { f.handlers['next:' + e] = fn; }};
    f.video(next);f.scan();const beforeReplace = f.events.length;oldEnded();oldError();check(f.events.length === beforeReplace, 'Detached provider video cannot retire the replacement player');
    f.context.RWTrailerCommand(true, true);f.handlers['next:timeupdate']();check(f.events.filter(e => e.event === 'state' && e.value === 1).length === beforeLate + 1, 'Replacement media can signal its own decoded frame');
    const b = fixture();let rejectPlay;
    b.video({paused:true,currentTime:0,readyState:0,videoWidth:0,videoHeight:0,addEventListener(){},play(){return {catch(fn){rejectPlay=fn;}};},pause(){}});b.scan();b.context.RWTrailerCommand(true,true);b.context.RWTrailerCommand(false,true);rejectPlay();check(!b.events.some(e => e.event === 'blocked'), 'An intentional pause is not misclassified as autoplay rejection');
    b.context.RWTrailerCommand(true,true);rejectPlay();check(b.events.some(e => e.event === 'blocked'), 'Actual visible autoplay rejection still reports failure');
    process.stdout.write(JSON.stringify({checks, failures: 0}));
}()).catch(error => { console.error(error);process.exitCode = 1; });
