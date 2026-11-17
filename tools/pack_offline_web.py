# -*- coding: utf-8 -*-
"""Packs the Godot web export so index.html runs when opened straight from disk.

Browsers refuse fetch() on file:// pages, so the engine could not load index.wasm,
index.pck, its audio worklets or the story clips. This script puts those files into
index.data.js (gzip + base64 for the big ones) and patches index.html so that
window.fetch and AudioWorklet.addModule are answered from that data by file name.

Usage:  python3 tools/pack_offline_web.py build/web <out_dir>
Run after the "Web" export and after copying assets/cine/*.ogv into build/web/cine/.
"""
import base64
import gzip
import json
import os
import shutil
import sys

LOADER = r'''<script src="index.data.js"></script>
		<script>
/* Serve the packed game data to the engine so the page also works as a local file. */
(function () {
	var F = window.NAKCHAL_FILES || {};
	var raw = window.fetch.bind(window);
	/* Opened straight out of the ZIP (data file missing): explain instead of failing. */
	if (!window.NAKCHAL_FILES && location.protocol === 'file:') {
		document.addEventListener('DOMContentLoaded', function () {
			var d = document.createElement('div');
			d.style.cssText = 'position:fixed;inset:0;z-index:10000;background:#12302a;color:#fbf6ea;font:600 18px/1.7 sans-serif;display:flex;align-items:center;justify-content:center;text-align:center;padding:24px';
			d.innerHTML = '<div><b style="display:block;font-size:34px;margin-bottom:12px;color:#ffb33f">압축을 먼저 풀어 주세요</b>' +
				'지금은 ZIP 파일 안에서 바로 열려서 게임 데이터를 찾지 못했어요.<br>ZIP 파일을 [압축 풀기] 한 뒤, 풀린 폴더의 index.html 을 다시 열어 주세요.</div>';
			document.body.appendChild(d);
		});
	}
	/* No service workers on file:// pages; answer "none registered" instead of throwing. */
	if (location.protocol === 'file:' && navigator.serviceWorker) {
		try {
			navigator.serviceWorker.getRegistration = function () { return Promise.resolve(undefined); };
			navigator.serviceWorker.getRegistrations = function () { return Promise.resolve([]); };
		} catch (e) {}
	}
	var cache = {};
	function key(url) {
		var u = String(url && url.url ? url.url : url).split('?')[0].split('#')[0];
		try { u = decodeURI(u); } catch (e) {}
		for (var k in F) { if (u === k || u.slice(-(k.length + 1)) === '/' + k) { return k; } }
		return null;
	}
	function blob(k) {
		if (!cache[k]) {
			var f = F[k];
			cache[k] = raw('data:application/octet-stream;base64,' + f.b64).then(function (r) { return r.blob(); }).then(function (b) {
				if (!f.gz) { return b; }
				return new Response(b.stream().pipeThrough(new DecompressionStream('gzip'))).blob();
			}).then(function (b) { return new Blob([b], { type: f.type }); });
		}
		return cache[k];
	}
	window.fetch = function (input, init) {
		var k = key(input);
		if (!k) { return raw(input, init); }
		return blob(k).then(function (b) {
			return new Response(b, { status: 200, headers: { 'Content-Type': F[k].type, 'Content-Length': String(F[k].size) } });
		});
	};
	/* Chrome will not load a worklet from a blob: URL made by a file:// page, but a data: URL works. */
	if (window.AudioWorklet && AudioWorklet.prototype.addModule) {
		var add = AudioWorklet.prototype.addModule;
		AudioWorklet.prototype.addModule = function (url, options) {
			var k = key(url);
			if (!k || F[k].gz) { return add.call(this, url, options); }
			return add.call(this, 'data:application/javascript;base64,' + F[k].b64, options);
		};
	}
})();
		</script>
		<script src="index.js"></script>'''


def main(web: str, out: str) -> None:
    os.makedirs(out, exist_ok=True)
    files = {}

    def add(rel: str, typ: str, gz: bool) -> None:
        data = open(os.path.join(web, rel), "rb").read()
        packed = gzip.compress(data, 9) if gz else data
        files[rel] = {"type": typ, "size": len(data), "gz": gz, "b64": base64.b64encode(packed).decode()}

    add("index.wasm", "application/wasm", True)
    add("index.pck", "application/octet-stream", True)
    add("index.audio.worklet.js", "application/javascript", False)
    add("index.audio.position.worklet.js", "application/javascript", False)
    cine = os.path.join(web, "cine")
    for name in sorted(os.listdir(cine)) if os.path.isdir(cine) else []:
        if name.endswith(".ogv"):
            add("cine/" + name, "video/ogg", False)
    with open(os.path.join(out, "index.data.js"), "w") as fh:
        fh.write("/* Game data packed for opening index.html directly (file://). */\nwindow.NAKCHAL_FILES=")
        json.dump(files, fh, separators=(",", ":"))
        fh.write(";\n")
    for name in ["index.js", "index.png", "index.icon.png", "index.apple-touch-icon.png"]:
        shutil.copy(os.path.join(web, name), out)
    html = open(os.path.join(web, "index.html"), encoding="utf-8").read()
    tag = '<script src="index.js"></script>'
    assert html.count(tag) == 1, "index.html layout changed"
    open(os.path.join(out, "index.html"), "w", encoding="utf-8").write(html.replace(tag, LOADER))
    print("packed:", ", ".join(f"{k} {v['size']}" for k, v in files.items()))


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
