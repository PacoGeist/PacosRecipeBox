import json, time, urllib.request, urllib.parse, urllib.error
UA = "RecipeAppSeedBuilder/0.1 (https://github.com/PacoGeist; patrick@bekdevelopers.com) python-urllib"
_last=[0]
def api(params, host="en.wikibooks.org"):
    params = dict(params, format="json", formatversion="2", maxlag="5")
    url = f"https://{host}/w/api.php?" + urllib.parse.urlencode(params)
    for i in range(10):
        wait = 1.5 - (time.time()-_last[0])
        if wait>0: time.sleep(wait)
        _last[0]=time.time()
        try:
            req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept-Encoding":"identity"})
            with urllib.request.urlopen(req, timeout=90) as r:
                return json.loads(r.read())
        except urllib.error.HTTPError as e:
            ra = e.headers.get("Retry-After")
            time.sleep(int(ra) if ra and ra.isdigit() else 20*(i+1))
        except Exception as e:
            time.sleep(5*(i+1))
    raise RuntimeError("failed " + url)
