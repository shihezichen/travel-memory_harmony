import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';

const DOMAIN: number = 0x0000;
const TAG: string = 'TravelMemory';

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
   * Lets the web app draw edge to edge (under the status bar) from the very
   * first frame; the page keeps its own controls clear with safe-area insets.
   */
  private prepareWindow(windowStage: window.WindowStage): void {
    try {
      const mainWindow: window.Window = windowStage.getMainWindowSync();
      mainWindow.setWindowLayoutFullScreen(true).catch((err: Error) => {
        hilog.warn(DOMAIN, TAG, 'setWindowLayoutFullScreen failed: %{public}s', JSON.stringify(err));
      });
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'prepareWindow failed: %{public}s', JSON.stringify(err));
    }
  }
}
