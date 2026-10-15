import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';

const DOMAIN: number = 0x0000;
const TAG: string = 'TravelMemory';

/**
 * Edge-to-edge layout: draw the web content underneath the status bar.
 *
 * Off by default: the page must itself use `viewport-fit=cover` plus
 * `env(safe-area-inset-*)` to keep its own top bar clear of the system bars.
 * The landing page does not do this and gets clipped, so we lay the web view
 * out below the status bar instead. Set to true once the pages handle insets.
 */
const IMMERSIVE: boolean = false;

/**
 * Entry ability of the Travel Memory web shell.
 *
 * The whole application is a single ArkWeb page (pages/Index) that renders the
 * self-hosted web app, so this ability only prepares the window and loads it.
 */
export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, TAG, 'Ability onCreate, launchReason=%{public}d', launchParam.launchReason);

    // Follow the system light / dark theme so the web view can react to it.
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'setColorMode failed: %{public}s', JSON.stringify(err));
    }
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, TAG, 'Ability onWindowStageCreate');

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, 'Failed to load content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, TAG, 'Succeeded in loading content.');
    });

    this.prepareWindow(windowStage);
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, TAG, 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, TAG, 'Ability onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, TAG, 'Ability onBackground');
  }

  /**
   * Lays the web view out below the system bars (unless `IMMERSIVE` is on), so
   * the page's own top bar is never hidden behind the status bar.
   */
  private prepareWindow(windowStage: window.WindowStage): void {
    try {
      const mainWindow: window.Window = windowStage.getMainWindowSync();
      mainWindow.setWindowLayoutFullScreen(IMMERSIVE).catch((err: Error) => {
        hilog.warn(DOMAIN, TAG, 'setWindowLayoutFullScreen failed: %{public}s', JSON.stringify(err));
      });
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'prepareWindow failed: %{public}s', JSON.stringify(err));
    }
  }
}
