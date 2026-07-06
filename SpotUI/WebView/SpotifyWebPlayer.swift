import WebKit

/// Hidden WKWebView playing real Spotify audio.
/// Port of SpotifyWebPlayer.kt — hosts Spotify's web player in a hidden WebView.
@MainActor
final class SpotifyWebPlayer: NSObject, ObservableObject {
    static let shared = SpotifyWebPlayer()

    private var webView: WKWebView?
    private var pageReady = false
    private var commandReady = false
    private var activated = false

    @Published var canPlay = false
    @Published var positionMs: Int64 = 0
    @Published var durationMs: Int64 = 0
    @Published var isPlaying = false

    var onStateChanged: (() -> Void)?

    private var pollTimer: Timer?

    private static let desktopUA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

    private override init() {
        super.init()
    }

    func attach(to window: UIWindow) {
        guard webView == nil else { return }

        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let wv = WKWebView(frame: .zero, configuration: config)
        wv.navigationDelegate = self
        wv.configuration.userContentController.add(self, name: "spotuiBridge")

        // Seed sp_dc cookie
        let spDc = SpotifySession.shared.spDc
        if !spDc.isEmpty {
            let store = wv.configuration.websiteDataStore.httpCookieStore
            let cookie = HTTPCookie(properties: [
                .domain: ".spotify.com",
                .path: "/",
                .name: "sp_dc",
                .value: spDc,
                .secure: true,
            ])!
            store.setCookie(cookie)
        }

        // Add off-screen but attached (required for audio)
        wv.translatesAutoresizingMaskIntoConstraints = false
        window.addSubview(wv)
        NSLayoutConstraint.activate([
            wv.widthAnchor.constraint(equalToConstant: 320),
            wv.heightAnchor.constraint(equalToConstant: 240),
            wv.topAnchor.constraint(equalTo: window.topAnchor, constant: -300),
        ])
        wv.scrollView.isScrollEnabled = false

        webView = wv
        wv.load(URLRequest(url: URL(string: "https://open.spotify.com/")!))
        startPolling()
    }

    func refreshLogin() {
        guard let wv = webView else { return }
        let spDc = SpotifySession.shared.spDc
        guard !spDc.isEmpty else { return }
        let store = wv.configuration.websiteDataStore.httpCookieStore
        let cookie = HTTPCookie(properties: [
            .domain: ".spotify.com",
            .path: "/",
            .name: "sp_dc",
            .value: spDc,
            .secure: true,
        ])!
        store.setCookie(cookie)
        commandReady = false
        activated = false
        wv.load(URLRequest(url: URL(string: "https://open.spotify.com/")!))
    }

    func play(trackId: String) {
        playUri("spotify:track:\(trackId)", path: "track/\(trackId)")
    }

    func playEpisode(episodeId: String) {
        playUri("spotify:episode:\(episodeId)", path: "episode/\(episodeId)")
    }

    private func playUri(_ uri: String, path: String) {
        guard let wv = webView else { return }
        if activated && commandReady {
            sendCommand(uri, path: path)
        } else {
            navigateAndPlay(wv, path: path)
            activated = true
        }
    }

    private func sendCommand(_ uri: String, path: String?) {
        guard let wv = webView else { return }
        wv.evaluateJavaScript("window.__spotuiPlay ? window.__spotuiPlay('\(uri)') : 'no-fn'") { [weak self] result, _ in
            guard let self else { return }
            let res = (result as? String) ?? ""
            if (res == "no-fn" || res == "no-device"), let path {
                Task { @MainActor in self.navigateAndPlay(wv, path: path) }
            }
        }
    }

    private func navigateAndPlay(_ wv: WKWebView, path: String) {
        wv.evaluateJavaScript("window.location.assign('https://open.spotify.com/\(path)')")
        for delay in [2.0, 3.0, 4.0, 5.0, 6.5, 8.0, 10.0, 12.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self else { return }
                wv.evaluateJavaScript(self.clickPlayJs()) { _, _ in }
            }
        }
    }

    func resume() { eval(clickPlayJs()) }
    func pause() { eval(pauseJs()) }
    func next() { eval(clickJs("control-button-skip-forward")) }
    func previous() { eval(clickJs("control-button-skip-back")) }

    func seekTo(positionMs: Int64) {
        guard let wv = webView, durationMs > 0 else { return }
        let frac = Double(positionMs) / Double(durationMs)
        wv.evaluateJavaScript(seekJs(frac))
        let pos = frac * Double(durationMs)
        self.positionMs = Int64(min(max(pos, 0), Double(durationMs)))
    }

    func release() {
        pollTimer?.invalidate()
        pollTimer = nil
        webView?.removeFromSuperview()
        webView = nil
        pageReady = false
        commandReady = false
        activated = false
    }

    // MARK: - Private helpers

    private func eval(_ js: String) {
        webView?.evaluateJavaScript(js)
    }

    private func startPolling() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.webView?.evaluateJavaScript(self?.progressJs() ?? "") { result, _ in
                    guard let self, let r = result as? String else { return }
                    let parts = r.split(separator: "|")
                    if parts.count == 3 {
                        if let pos = Double(parts[0]), pos >= 0 { self.positionMs = Int64(pos * 1000) }
                        if let dur = Double(parts[1]), dur >= 0 { self.durationMs = Int64(dur * 1000) }
                        self.isPlaying = parts[2] == "1"
                        self.onStateChanged?()
                    }
                }
            }
        }
    }

    // MARK: - JS scripts

    private func clickPlayJs() -> String {
        """
        (function(){
          var pp=document.querySelector('[data-testid="control-button-playpause"]');
          if(pp&&(pp.getAttribute('aria-label')||'').toLowerCase().indexOf('pause')>-1) return 'already-playing';
          var b=document.querySelector('[data-testid="play-button"]');
          if(b&&(b.getAttribute('aria-label')||'').toLowerCase().indexOf('pause')===-1){b.click();return 'clicked';}
          return 'no-play-button';
        })();
        """
    }

    private func pauseJs() -> String {
        """
        (function(){
          var b=document.querySelector('[data-testid="control-button-playpause"]');
          if(b){var lbl=(b.getAttribute('aria-label')||'').toLowerCase();
            if(lbl.indexOf('pause')!==-1){b.click();return 'paused';}}
          return 'not-playing';
        })();
        """
    }

    private func clickJs(_ testId: String) -> String {
        """
        (function(){var b=document.querySelector('[data-testid "\(testId)"]');
          if(b){b.click();return 'clicked';}return 'missing';})();
        """
    }

    private func seekJs(_ frac: Double) -> String {
        """
        (function(){
          var f=\(frac);
          var input=document.querySelector('[data-testid="playback-progressbar"] input[type="range"]')
                 ||document.querySelector('[data-testid="progress-bar"] input[type="range"]');
          if(input){
            var max=parseFloat(input.max)||1,val=f*max;
            var setter=Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype,'value').set;
            setter.call(input,String(val));
            input.dispatchEvent(new Event('input',{bubbles:true}));
            input.dispatchEvent(new Event('change',{bubbles:true}));
            return 'input '+val.toFixed(1)+'/'+max;
          }
          return 'no-bar';
        })();
        """
    }

    private func progressJs() -> String {
        """
        (function(){
          function t2s(t){if(!t)return -1;var p=t.trim().split(':');if(!p.length)return -1;
            var s=0;for(var i=0;i<p.length;i++){var n=parseInt(p[i],10);if(isNaN(n))return -1;s=s*60+n;}return s;}
          var pe=document.querySelector('[data-testid="playback-position"]');
          var de=document.querySelector('[data-testid="playback-duration"]');
          var pp=document.querySelector('[data-testid="control-button-playpause"]');
          var playing=(pp&&(pp.getAttribute('aria-label')||'').toLowerCase().indexOf('pause')>-1)?'1':'0';
          return t2s(pe&&pe.textContent)+'|'+t2s(de&&de.textContent)+'|'+playing;
        })();
        """
    }
}

// MARK: - WKNavigationDelegate + WKScriptMessageHandler

extension SpotifyWebPlayer: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        // Inject visibility spoof early
        let js = """
        (function(){
          try {
            var vis=function(){return 'visible';};
            var no=function(){return false;};
            Object.defineProperty(document,'visibilityState',{configurable:true,get:vis});
            Object.defineProperty(document,'hidden',{configurable:true,get:no});
            document.hasFocus=function(){return true;};
          } catch(e){}
        })();
        """
        webView.evaluateJavaScript(js)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor in
            pageReady = webView.url?.host == "open.spotify.com"
            // Bootstrap JS for command API
            webView.evaluateJavaScript(SpotifyWebPlayer.BOOTSTRAP_JS)
            // Probe Widevine
            webView.evaluateJavaScript("""
            (function(){
              try {
                navigator.requestMediaKeySystemAccess('com.widevine.alpha',
                  [{initDataTypes:['cenc'],audioCapabilities:[{contentType:'audio/mp4;codecs="mp4a.40.2"'}]}])
                  .then(function(){ window.webkit.messageHandlers.spotuiBridge.postMessage({type:'widevine',ok:true}); })
                  .catch(function(){ window.webkit.messageHandlers.spotuiBridge.postMessage({type:'widevine',ok:false}); });
              } catch(e) { window.webkit.messageHandlers.spotuiBridge.postMessage({type:'widevine',ok:false}); }
            })();
            """)
        }
    }
}

extension SpotifyWebPlayer: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let type = body["type"] as? String else { return }
        Task { @MainActor in
            switch type {
            case "widevine":
                canPlay = body["ok"] as? Bool ?? false
            case "commandReady":
                commandReady = true
            default:
                break
            }
        }
    }
}

// MARK: - Bootstrap JS

extension SpotifyWebPlayer {
    static let BOOTSTRAP_JS = """
    (function(){
      if(window.__spotuiReady) return;
      window.__spotuiReady=true;
      window.__featVer='web-player_'+Date.now();
      var oriFetch=window.fetch.bind(window);
      window.__oriFetch=oriFetch;
      window.fetch=function(){
        try{
          var url=arguments[0],opts=arguments[1]||{};
          var us=(typeof url==='string')?url:(url&&url.url)||'';
          var hs=opts.headers||{};
          function hv(n){try{return hs.get?hs.get(n):(hs[n]||hs[n.toLowerCase()]);}catch(e){return null;}}
          if(us.indexOf('/track-playback/v1/devices')>-1&&opts.body){
            try{var b=JSON.parse(opts.body);if(b&&b.device&&b.device.device_id)window.__devId=b.device.device_id;}catch(e){}
          }
          var ct=hv('Client-Token');if(ct)window.__cliToken=ct;
          var au=hv('Authorization');if(au&&au.indexOf('Bearer')===0)window.__auth=au;
          if(window.__devId&&window.__auth&&!window.__reported){
            window.__reported=true;
            try{window.webkit.messageHandlers.spotuiBridge.postMessage({type:'commandReady'});}catch(e){}
          }
        }catch(e){}
        return oriFetch.apply(this,arguments);
      };
      window.__spotuiPlay=function(uri){
        if(!window.__devId||!window.__auth)return 'no-device';
        var base=window.__spBase||'https://gew4-spclient.spotify.com';
        var type=(uri.match(/^spotify:([^:]+)/)||[])[1]||'track';
        window.__oriFetch(base+'/connect-state/v1/player/command/from/'+window.__devId+'/to/'+window.__devId,{
          method:'POST',
          headers:{'Authorization':window.__auth,'Client-Token':window.__cliToken||'','Content-Type':'application/json'},
          body:JSON.stringify({command:{context:{uri:uri,url:'context://'+uri,metadata:{}},play_origin:{feature_identifier:type,feature_version:window.__featVer,referrer_identifier:'search'},options:{license:'tft',skip_to:{},player_options_override:{}},endpoint:'play'}})
        }).catch(function(){});
        return 'sent';
      };
    })();
    """
}
