import { webview } from '@kit.ArkWeb';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { common } from '@kit.AbilityKit';

const TAG: string = 'TravelMemory';
const DOMAIN: number = 0x0000;
const SERVER_URL: string = 'https://top001.xin';

@Entry
@Component
struct Index {
  @State isRefreshing: boolean = false;
  controller: webview.WebviewController = new webview.WebviewController();
  @State progress: number = 0;
  @State loading: boolean = true;
  @State loadError: boolean = false;

  aboutToAppear(): void {
    webview.WebviewController.initializeWebEngine({
      src: SERVER_URL,
      controller: this.controller
    });
  }

  build() {
    Stack() {
      Refresh({ refreshing: $$this.isRefreshing }) {
        Web({ src: SERVER_URL, controller: this.controller }) {
          // allow navigation inside the app; external links open via system browser
        }
        .width('100%')
        .height('100%')
        .javaScriptAccess(true)
        .domStorageAccess(true)
        .fileAccess(false)
      .onControllerAttached(() => {
        hilog.info(DOMAIN, TAG, 'web controller attached');
      })
      .onPageBegin(() => {
        this.loading = true;
        this.loadError = false;
      })
      .onPageEnd(() => {
        this.loading = false;
      })
      .onProgressChange((progress: number) => {
        this.progress = progress;
      })
      .onErrorReceive((event) => {
        // only main-frame errors flip the error page
        if (event && event.request.isMainFrame()) {
          this.loadError = true;
          this.loading = false;
          hilog.error(DOMAIN, TAG, 'web error: %{public}s', event.error.getErrorInfo());
        }
      })
      .onRefreshAccessedHistory((event) => {
        if (event && event.isRefreshed) {
          hilog.info(DOMAIN, TAG, 'visited: %{public}s', event.url);
        }
      })
      .onLoadIntercept((event) => {
        // external links -> system browser; keep same-host navigation inside the app
        if (!event) {
          return false;
        }
        const url = event.data.getRequestUrl();
        if (!url.startsWith('http')) {
          return false; // let non-http schemes (mailto etc.) fail silently or default
        }
        if (url.startsWith(SERVER_URL)) {
          return false;
        }
        try {
          const context = getContext(this) as common.UIAbilityContext;
          context.openLink(url, { appLinkingOnly: false });
          hilog.info(DOMAIN, TAG, 'external link -> system: %{public}s', url);
        } catch (e) {
          hilog.error(DOMAIN, TAG, 'openLink failed: %{public}s', JSON.stringify(e));
        }
        return true;
      })
      }
      .onRefreshing(() => {
        try {
          this.controller.refresh();
        } catch (e) {
          this.controller.loadUrl(SERVER_URL);
        }
        // stop the spinner shortly after; onPageEnd also signals completion
        setTimeout(() => {
          this.isRefreshing = false;
        }, 1500);
      })
      .width('100%')
      .height('100%')

      if (this.loading && !this.loadError) {
        Column() {
          LoadingProgress()
            .width(48)
            .height(48)
            .color('#F97316')
          Text(`正在连接 ${SERVER_URL} … ${this.progress}%`)
            .fontSize(14)
            .margin({ top: 12 })
            .fontColor('#666666')
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor('#FFFFFF')
      }

      if (this.loadError) {
        Column({ space: 16 }) {
          Text('无法连接到 Travel Memory 服务器')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
          Text('请检查网络后重试')
            .fontSize(14)
            .fontColor('#666666')
          Button('重新加载')
            .onClick(() => {
              this.loadError = false;
              this.loading = true;
              try {
                this.controller.refresh();
              } catch (e) {
                this.controller.loadUrl(SERVER_URL);
              }
            })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor('#FFFFFF')
      }
    }
  }
}
