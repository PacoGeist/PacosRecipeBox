"""Run after `flutter build web`: lists files for offline caching and stamps sw.js with a build version."""
import json, os, sys, time
root = sys.argv[1] if len(sys.argv) > 1 else 'build/web'
skip = {'sw.js', 'sw_files.json', '.last_build_id', 'flutter_service_worker.js'}
files = []
for d, _, fs in os.walk(root):
    for f in fs:
        rel = os.path.relpath(os.path.join(d, f), root).replace(os.sep, '/')
        if rel in skip or rel.endswith('.map') or rel.endswith('.symbols'):
            continue
        # Safari/iOS uses the plain CanvasKit build; other engine variants are fetched only if a browser needs them.
        if rel.startswith('canvaskit/') and rel not in ('canvaskit/canvaskit.js', 'canvaskit/canvaskit.wasm'):
            continue
        files.append(rel)
files.sort()
json.dump(files, open(os.path.join(root, 'sw_files.json'), 'w'))
ver = json.load(open(os.path.join(root, 'version.json'))).get('version', '0') + '-' + str(int(time.time()))
p = os.path.join(root, 'sw.js')
src = open(p).read()
open(p, 'w').write(src.replace('__BUILD_VERSION__', ver))
print(len(files), 'files listed; sw version', ver)
