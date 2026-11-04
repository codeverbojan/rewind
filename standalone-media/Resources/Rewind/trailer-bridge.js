/* iOS 9 compatibility for the official embedded page; no media URL extraction. */
(function () {
    'use strict';
    var before = {queueMicrotask: typeof window.queueMicrotask === 'function', globalThis: typeof window.globalThis !== 'undefined'};
    if (!before.globalThis) Object.defineProperty(window, 'globalThis', {value: window, writable: true, configurable: true});
    if (!before.queueMicrotask) {
        var resolved = Promise.resolve();
        window.queueMicrotask = function (callback) {
            if (typeof callback !== 'function') throw new TypeError('queueMicrotask requires a function');
            resolved.then(callback).catch(function (error) { setTimeout(function () { throw error; }, 0); });
        };
    }
    var video = null, ready = false, started = false, lastError = '', wanted = false, muted = true, apiSeen = false;
    var errors = [], resources = [];
    function send(event, value) {
        try { window.webkit.messageHandlers.rewindTrailer.postMessage({event: event, value: value || 0}); } catch (ignore) {}
    }
    send('compatibility', before);
    function apply() {
        var api = document.getElementById('movie_player');
        if (api && typeof api.playVideo === 'function') {
            if (muted && api.mute) api.mute();
            else if (!muted && api.unMute) api.unMute();
            if (wanted) api.playVideo();
            else if (api.pauseVideo) api.pauseVideo();
            return;
        }
        if (!video) return;
        video.muted = muted;
        if (wanted) {
            var pending = video.play();
            if (pending && pending.catch) pending.catch(function () { if (wanted) send('blocked'); });
        } else video.pause();
    }
    window.RWTrailerCommand = function (play, mute) { wanted = play; muted = mute; apply(); };
    function available() { if (!ready && video) { ready = true; send('ready'); } }
    function playing() {
        if (wanted && video && video.currentTime > 0 && !video.paused && video.readyState >= 2 && video.videoWidth > 0 && video.videoHeight > 0) {
            available();
            if (!started) { started = true; send('state', 1); }
        }
    }
    window.addEventListener('error', function (event) {
        if (event.message && errors.length < 8) {
            errors.push({message: String(event.message).substring(0, 240), file: String(event.filename || '').substring(0, 260), line: event.lineno || 0});
            send('script_errors', errors.slice());
        } else if (event.target && event.target.tagName === 'SCRIPT' && resources.length < 6) {
            resources.push(String(event.target.src || '').substring(0, 300));
            send('resource_errors', resources.slice());
        }
    }, true);
    function scan() {
        var api = document.getElementById('movie_player');
        if (!apiSeen && api && typeof api.playVideo === 'function') { apiSeen = true; send('ready'); }
        var current = document.querySelector('video');
        if (current && current !== video) {
            video = current; ready = false; started = false;
            video.addEventListener('loadedmetadata', function () { if (video === current) available(); });
            video.addEventListener('loadeddata', function () { if (video === current) available(); });
            video.addEventListener('playing', function () { if (video !== current) return; started = false; playing(); });
            video.addEventListener('timeupdate', function () { if (video === current) playing(); });
            video.addEventListener('pause', function () { if (video !== current) return; started = false; send('state', 2); });
            video.addEventListener('ended', function () { if (video === current) send('state', 0); });
            video.addEventListener('error', function () { if (video === current) send('media_error', video.error ? video.error.code : 0); });
            available(); playing();
        }
        var element = document.querySelector('.ytp-error-content-wrap');
        var text = element ? (element.textContent || '').replace(/\s+/g, ' ').substring(0, 220) : '';
        if (text && text !== lastError) { lastError = text; send('player_error_text', text); }
    }
    document.addEventListener('DOMContentLoaded', function () { send('document_loaded'); scan(); });
    setInterval(scan, 500);
}());
