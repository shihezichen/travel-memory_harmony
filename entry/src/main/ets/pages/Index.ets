import { webview } from '@kit.ArkWeb';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { window } from '@kit.ArkUI';
import { http } from '@kit.NetworkKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { APP_UA_SUFFIX, ERR_ABORTED, IMMERSIVE, SERVER_HOST, SERVER_URL } from '../common/AppConfig';

/**
 * JS bridge object injected into the web view. The web page calls
 * `window.hmSmartWebviewBridge.saveToGallery(url, name)` (see tmNativeDownload
 * in the web repo); we forward it to the page component which downloads the
 * media with the web session cookie and saves it into the system gallery.
 */
class GalleryBridge {
  private owner: Index;
  constructor(owner: Index) {
    this.owner = owner;
  }
  saveToGallery(url: string, name: string): void {
    this.owner.saveMediaToGallery(url, name);
  }
}

const DOMAIN: number = 0x0000;
const TAG: string = 'TravelMemory';

/**
 * The whole application: a full screen ArkWeb view pointing at the Travel
 * Memory server, wrapped with the mobile affordances a website cannot provide
 * by itself (pull to refresh, hardware back, gallery upload, media download,
 * geolocation and camera/microphone permissions).
 */
@Entry
@Component
struct Index {
  @State isRefreshing: boolean = false;
  @State progress: number = 0;
  @State loading: boolean = true;
  @State loadError: boolean = false;
  @State errorMessage: string = '';
  @State firstLoadDone: boolean = false;

  private controller: webview.WebviewController = new webview.WebviewController();
  private downloadDelegate: webview.WebDownloadDelegate = new webview.WebDownloadDelegate();
  private downloadDir: string = '';
  private staticSetupDone: boolean = false;
  private lastFailedUrl: string = SERVER_URL;

  aboutToAppear(): void {
    // Initialise the web engine before the Web component is created so the
    // first paint is as fast as possible.
    try {
      webview.WebviewController.initializeWebEngine();
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'initializeWebEngine failed: %{public}s', JSON.stringify(err));
    }
  }

  /**
   * Hardware / gesture back: walk the web history first, and only let the
   * system close the app once we are at the first page.
   */
  onBackPress(): boolean {
    try {
      if (this.controller.accessBackward()) {
        this.controller.backward();
        return true;
      }
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'back failed: %{public}s', JSON.stringify(err));
    }
    return false;
  }

  /** Re-assert the immersive chrome whenever the page is (re)shown. */
  onPageShow(): void {
    this.applyImmersiveChrome();
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Refresh({ refreshing: $$this.isRefreshing }) {
        Web({ src: SERVER_URL, controller: this.controller })
          .width('100%')
          .height('100%')
          .backgroundColor('#FFF6EE')
          .javaScriptAccess(true)
          .domStorageAccess(true)
          .databaseAccess(true)
          .onlineImageAccess(true)
          .imageAccess(true)
          .fileAccess(false)
          .zoomAccess(false)
          .geolocationAccess(true)
          .mixedMode(MixedMode.Compatible)
          .cacheMode(CacheMode.Default)
          .darkMode(WebDarkMode.Auto)
          .mediaPlayGestureAccess(false)
          .onControllerAttached(() => {
            this.onControllerAttached();
          })
          .onPageBegin(() => {
            this.loading = true;
            this.loadError = false;
          })
          .onPageEnd(() => {
            this.loading = false;
            this.firstLoadDone = true;
            this.isRefreshing = false;
            this.progress = 100;
            this.applyImmersiveChrome();
          })
          .onProgressChange((event) => {
            this.progress = event.newProgress;
          })
          .onErrorReceive((event) => {
            if (event && event.request.isMainFrame() && event.error.getErrorCode() !== ERR_ABORTED) {
              this.showError(event.error.getErrorInfo(), event.request.getRequestUrl());
            }
          })
          .onSslErrorEventReceive((event) => {
            if (event) {
              hilog.error(DOMAIN, TAG, 'SSL error: %{public}d', event.error);
              event.handler.handleCancel();
              this.showError('证书校验失败，无法建立安全连接', this.controller.getUrl());
            }
          })
          .onRenderExited((event) => {
            hilog.warn(DOMAIN, TAG, 'render exited: %{public}d', event.renderExitReason);
            this.reload();
          })
          .onLoadIntercept((event) => {
            return this.onLoadIntercept(event);
          })
          .onGeolocationShow((event) => {
            this.handleGeolocation(event.origin, event.geolocation);
          })
          .onPermissionRequest((event) => {
            this.handlePermissionRequest(event.request);
          })
          .onRefreshAccessedHistory((event) => {
            if (event && event.isRefreshed) {
              hilog.info(DOMAIN, TAG, 'history refreshed: %{public}s', event.url);
            }
          })
      }
      .onRefreshing(() => {
        this.refreshCurrentPage();
      })
      .width('100%')
      .height('100%')

      // Thin progress bar shown while a page is loading.
      if (this.loading && !this.loadError && this.progress < 100) {
        Progress({ value: this.progress, total: 100, type: ProgressType.Linear })
          .width('100%')
          .height(3)
          .color('#F97316')
          .backgroundColor('#00000000')
      }

      // Start-up splash: hides the blank web surface during the very first load.
      if (this.loading && !this.loadError && !this.firstLoadDone) {
        Column({ space: 14 }) {
          LoadingProgress()
            .width(52)
            .height(52)
            .color('#F97316')
          Text('正在打开旅行记忆…')
            .fontSize(14)
            .fontColor('#8A5A2B')
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor('#FFF6EE')
      }

      // Offline / failure screen.
      if (this.loadError) {
        Column({ space: 14 }) {
          Text('🧭')
            .fontSize(52)
          Text('暂时无法连接到旅行记忆')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor('#3B2A16')
          Text(this.errorMessage.length > 0 ? this.errorMessage : '请检查网络连接后重试')
            .fontSize(13)
            .fontColor('#8A5A2B')
            .textAlign(TextAlign.Center)
            .padding({ left: 32, right: 32 })
          Button('重新加载')
            .fontSize(16)
            .fontColor(Color.White)
            .backgroundColor('#F97316')
            .padding({ left: 30, right: 30, top: 10, bottom: 10 })
            .margin({ top: 8 })
            .onClick(() => {
              this.retry();
            })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor('#FFF6EE')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFF6EE')
  }

  /* ------------------------------------------------------------------ */
  /* Web lifecycle helpers                                              */
  /* ------------------------------------------------------------------ */

  private onControllerAttached(): void {
    hilog.info(DOMAIN, TAG, 'web controller attached');
    this.setupDownloads();
    this.registerGalleryBridge();
    try {
      // Keep the native user agent intact and just append a marker so the
      // server can tell the app apart from a plain mobile browser.
      const ua: string = this.controller.getUserAgent();
      if (ua.length > 0 && ua.indexOf('TravelMemoryHarmony') < 0) {
        this.controller.setCustomUserAgent(ua + APP_UA_SUFFIX);
      }
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'userAgent setup failed: %{public}s', JSON.stringify(err));
    }
    try {
      this.controller.setDownloadDelegate(this.downloadDelegate);
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'setDownloadDelegate failed: %{public}s', JSON.stringify(err));
    }
  }

  /* ------------------------------------------------------------------ */
  /* Immersive chrome (edge to edge without clipping)                    */
  /* ------------------------------------------------------------------ */

  /**
   * The web app is written for a browser, where the status bar sits outside the
   * viewport, so its own top bars do not reserve the notch. With the window laid
   * out edge to edge we push exactly those bars down by the real status bar
   * height, and colour the status bar icons to match the page.
   */
  private async applyImmersiveChrome(): Promise<void> {
    if (!IMMERSIVE) {
      return;
    }
    try {
      const mainWindow: window.Window = await window.getLastWindow(this.uiContext());
      const avoidArea: window.AvoidArea = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      const topVp: number = Math.round(this.getUIContext().px2vp(avoidArea.topRect.height));
      if (topVp <= 0) {
        return;
      }
      const tone: string = await this.controller.runJavaScript(this.buildInsetScript(topVp));
      await mainWindow.setWindowSystemBarProperties({
        statusBarContentColor: tone.indexOf('dark') >= 0 ? '#FFFFFF' : '#000000'
      });
      hilog.info(DOMAIN, TAG, 'immersive chrome: top=%{public}d tone=%{public}s', topVp, tone);
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'applyImmersiveChrome failed: %{public}s', JSON.stringify(err));
    }
  }

  /**
   * Adds the notch padding to the page's own top chrome (idempotent) and reports
   * the page tone back so the status bar icons stay readable.
   *
   * A page that already reserves the notch itself advertises it with
   * `<meta name="tm-safe-area" content="1">` (see static/index.html in the web
   * repo); when it does, we only read the tone and inject nothing, otherwise the
   * padding would be applied twice.
   */
  private buildInsetScript(topVp: number): string {
    return `(function(){try{
      if(!document.body)return 'nobody';
      var bg=getComputedStyle(document.body).backgroundColor||'';
      var n=bg.match(/[0-9]+/g)||[];
      var r=parseInt(n[0]||'255',10),g=parseInt(n[1]||'255',10),b=parseInt(n[2]||'255',10);
      var dark=(0.299*r+0.587*g+0.114*b)<140;
      if(!window.__tmSafe){
        window.__tmSafe=1;
        if(!document.querySelector('meta[name=tm-safe-area]')){
          var px=${topVp};
          var mv=document.querySelector('meta[name=viewport]');
          if(mv){var c=mv.getAttribute('content')||'';if(c.indexOf('viewport-fit')<0)mv.setAttribute('content',c+', viewport-fit=cover');}
          var st=document.createElement('style');
          st.id='tm-safe-area';
          st.textContent='header{padding-top:'+px+'px !important}.topbar{padding-top:'+px+'px !important}';
          document.head.appendChild(st);
        }
      }
      return dark?'dark':'light';
    }catch(e){return 'err:'+e}})()`;
  }

  /**
   * Pull-to-refresh: reload the page the user is currently looking at.
   */
  private refreshCurrentPage(): void {
    this.loading = true;
    try {
      this.controller.refresh();
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'refresh failed: %{public}s', JSON.stringify(err));
      this.isRefreshing = false;
      this.retry();
      return;
    }
    // Safety net: never leave the refresh indicator spinning forever.
    setTimeout(() => {
      this.isRefreshing = false;
    }, 8000);
  }

  /**
   * Retry the URL that failed to load (falls back to the home page).
   */
  private retry(): void {
    this.loadError = false;
    this.errorMessage = '';
    this.loading = true;
    const target: string = this.lastFailedUrl.length > 0 ? this.lastFailedUrl : SERVER_URL;
    try {
      this.controller.loadUrl(target);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'retry failed: %{public}s', JSON.stringify(err));
    }
  }

  private reload(): void {
    this.retry();
  }

  private showError(message: string, failedUrl: string): void {
    this.loadError = true;
    this.loading = false;
    this.isRefreshing = false;
    this.errorMessage = message;
    if (failedUrl && failedUrl.length > 0) {
      this.lastFailedUrl = failedUrl;
    }
    hilog.error(DOMAIN, TAG, 'load error: %{public}s', message);
  }

  /* ------------------------------------------------------------------ */
  /* External links                                                     */
  /* ------------------------------------------------------------------ */

  private onLoadIntercept(event: OnLoadInterceptEvent): boolean {
    if (!event) {
      return false;
    }
    const url: string = event.data.getRequestUrl();
    if (!url || url.length === 0) {
      return false;
    }
    if (url.indexOf('http://') === 0 || url.indexOf('https://') === 0) {
      if (this.isInternalUrl(url)) {
        return false; // keep navigation inside the app
      }
      this.openExternally(url);
      return true;
    }
    if (url.indexOf('mailto:') === 0 || url.indexOf('tel:') === 0 || url.indexOf('sms:') === 0) {
      this.openExternally(url);
      return true;
    }
    return false;
  }

  private isInternalUrl(url: string): boolean {
    const host: string = this.hostOf(url);
    return host === SERVER_HOST || host.endsWith('.' + SERVER_HOST);
  }

  private hostOf(url: string): string {
    const schemeIdx: number = url.indexOf('://');
    if (schemeIdx < 0) {
      return '';
    }
    let rest: string = url.substring(schemeIdx + 3);
    const slash: number = this.firstIndexOfAny(rest, '/?#');
    if (slash >= 0) {
      rest = rest.substring(0, slash);
    }
    const at: number = rest.lastIndexOf('@');
    if (at >= 0) {
      rest = rest.substring(at + 1);
    }
    const colon: number = rest.lastIndexOf(':');
    if (colon >= 0) {
      rest = rest.substring(0, colon);
    }
    return rest.toLowerCase();
  }

  private firstIndexOfAny(value: string, chars: string): number {
    for (let i = 0; i < value.length; i++) {
      if (chars.indexOf(value.charAt(i)) >= 0) {
        return i;
      }
    }
    return -1;
  }

  private uiContext(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  private toast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message, duration: 2000 });
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'showToast failed: %{public}s', JSON.stringify(err));
    }
  }

  private openExternally(url: string): void {
    const context = this.uiContext();
    context.openLink(url, { appLinkingOnly: false })
      .then(() => {
        hilog.info(DOMAIN, TAG, 'opened externally: %{public}s', url);
      })
      .catch((err: BusinessError) => {
        hilog.error(DOMAIN, TAG, 'openLink failed: %{public}s', JSON.stringify(err));
        this.toast('无法打开链接');
      });
  }

  /* ------------------------------------------------------------------ */
  /* Permissions (geolocation / camera / microphone)                    */
  /* ------------------------------------------------------------------ */

  private handleGeolocation(origin: string, geolocation: JsGeolocation): void {
    const permissions: Array<Permissions> =
      ['ohos.permission.APPROXIMATELY_LOCATION', 'ohos.permission.LOCATION'];
    this.ensurePermissions(permissions)
      .then((granted: boolean) => {
        geolocation.invoke(origin, granted, false);
      })
      .catch(() => {
        geolocation.invoke(origin, false, false);
      });
  }

  private handlePermissionRequest(request: PermissionRequest): void {
    const resources: Array<string> = request.getAccessibleResource();
    const permissions: Array<Permissions> = [];
    for (const resource of resources) {
      if (resource === 'TYPE_VIDEO_CAPTURE' && permissions.indexOf('ohos.permission.CAMERA') < 0) {
        permissions.push('ohos.permission.CAMERA');
      } else if (resource === 'TYPE_AUDIO_CAPTURE' && permissions.indexOf('ohos.permission.MICROPHONE') < 0) {
        permissions.push('ohos.permission.MICROPHONE');
      }
    }
    if (permissions.length === 0) {
      request.deny();
      return;
    }
    this.ensurePermissions(permissions)
      .then((granted: boolean) => {
        if (granted) {
          request.grant(resources);
        } else {
          request.deny();
        }
      })
      .catch(() => {
        request.deny();
      });
  }

  private async ensurePermissions(permissions: Array<Permissions>): Promise<boolean> {
    const context = this.uiContext();
    const atManager = abilityAccessCtrl.createAtManager();
    try {
      const result = await atManager.requestPermissionsFromUser(context, permissions);
      const authResults: Array<number> = result.authResults;
      for (let i = 0; i < authResults.length; i++) {
        if (authResults[i] !== 0) {
          return false;
        }
      }
      return true;
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'requestPermissions failed: %{public}s', JSON.stringify(err));
      return false;
    }
  }

  /* ------------------------------------------------------------------ */
  /* Media download                                                     */
  /* ------------------------------------------------------------------ */

  private setupDownloads(): void {
    if (this.staticSetupDone) {
      return;
    }
    this.staticSetupDone = true;
    const context = this.uiContext();
    this.downloadDir = context.filesDir + '/downloads';
    try {
      if (!fs.accessSync(this.downloadDir)) {
        fs.mkdirSync(this.downloadDir);
      }
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'cannot create download dir: %{public}s', JSON.stringify(err));
    }

    this.downloadDelegate.onBeforeDownload((item: webview.WebDownloadItem) => {
      const path: string = this.uniqueDownloadPath(item.getSuggestedFileName());
      try {
        item.start(path);
        hilog.info(DOMAIN, TAG, 'download started: %{public}s', path);
      } catch (err) {
        hilog.error(DOMAIN, TAG, 'download start failed: %{public}s', JSON.stringify(err));
        item.cancel();
      }
    });
    this.downloadDelegate.onDownloadFinish((item: webview.WebDownloadItem) => {
      const name: string = this.fileNameOf(item.getFullPath());
      this.toast('已保存：' + name);
      hilog.info(DOMAIN, TAG, 'download finished: %{public}s', item.getFullPath());
    });
    this.downloadDelegate.onDownloadFailed((item: webview.WebDownloadItem) => {
      this.toast('下载失败，请重试');
      hilog.error(DOMAIN, TAG, 'download failed: %{public}d', item.getLastErrorCode());
    });
  }

  /* ------------------------------------------------------------------ */
  /* Native download bridge                                              */
  /* ------------------------------------------------------------------ */

  /**
   * Injects `window.hmSmartWebviewBridge.saveToGallery(url, name)` into the page.
   * The web repo (tmNativeDownload) already knows this name, so once the bridge
   * exists the page stops using window.open() and calls us directly - we then
   * download the file with the web session cookie and drop it into the system
   * photo gallery (so it shows up in the album, not just inside the app).
   */
  private registerGalleryBridge(): void {
    try {
      this.controller.registerJavaScriptProxy(new GalleryBridge(this), 'hmSmartWebviewBridge', ['saveToGallery']);
      hilog.info(DOMAIN, TAG, 'gallery bridge registered');
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'registerJavaScriptProxy failed: %{public}s', JSON.stringify(err));
    }
  }

  private async saveMediaToGallery(url: string, name: string): Promise<void> {
    if (!url || url.length === 0) {
      this.toast('下载地址为空');
      return;
    }
    const granted: boolean = await this.ensurePermissions(['ohos.permission.WRITE_IMAGEVIDEO']);
    if (!granted) {
      this.toast('没有相册权限，无法保存');
      return;
    }
    try {
      // The web login cookie (tm_token) lives in the ArkWeb cookie jar; pull it
      // out and send it with the native request, otherwise the download API
      // returns 401/404. Different SDK versions expose fetchCookie / getCookie,
      // so probe both.
      const cm: any = webview.WebCookieManager;
      let cookie: string = '';
      try {
        cookie = (typeof cm.fetchCookie === 'function' ? cm.fetchCookie(url) : '')
          || (typeof cm.getCookie === 'function' ? cm.getCookie(url) : '')
          || '';
      } catch (e) {
        cookie = '';
      }
      const isVideo: boolean = /\.(mp4|webm|mov|m4v|avi)$/i.test(name || '');
      const httpRequest = http.createHttp();
      const response = await httpRequest.request(url, {
        method: http.RequestMethod.GET,
        header: cookie ? { 'Cookie': cookie } : {},
        expectDataType: http.HttpDataType.ARRAY_BUFFER
      });
      httpRequest.destroy();
      if (response.responseCode !== 200) {
        this.toast('下载失败：' + response.responseCode);
        return;
      }
      const buf: ArrayBuffer = response.result as ArrayBuffer;
      const context = this.uiContext();
      const ph = photoAccessHelper.getPhotoAccessHelper(context);
      const ext: string = isVideo ? 'mp4' : 'jpg';
      const photoType = isVideo ? photoAccessHelper.PhotoType.VIDEO : photoAccessHelper.PhotoType.IMAGE;
      const assetUri: string = await ph.createAsset(photoType, ext);
      const file = fs.openSync(assetUri, fs.OpenMode.READ_WRITE);
      fs.writeSync(file.fd, buf);
      fs.closeSync(file.fd);
      this.toast('已保存到相册：' + (name || '媒体'));
      hilog.info(DOMAIN, TAG, 'saved to gallery: %{public}s', assetUri);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'saveMediaToGallery failed: %{public}s', JSON.stringify(err));
      this.toast('保存失败，请重试');
    }
  }

  private uniqueDownloadPath(suggestedName: string): string {
    let name: string = this.sanitizeFileName(suggestedName);
    let path: string = this.downloadDir + '/' + name;
    try {
      if (fs.accessSync(path)) {
        name = Date.now().toString() + '-' + name;
        path = this.downloadDir + '/' + name;
      }
    } catch (err) {
      // accessSync throwing means the file does not exist - keep the name.
    }
    return path;
  }

  private sanitizeFileName(suggestedName: string): string {
    let name: string = suggestedName;
    if (!name || name.length === 0) {
      name = 'travel-memory-' + Date.now().toString();
    }
    name = name.replace(/[\\/:*?"<>|]/g, '_');
    return name;
  }

  private fileNameOf(path: string): string {
    const slash: number = path.lastIndexOf('/');
    return slash >= 0 ? path.substring(slash + 1) : path;
  }
}
