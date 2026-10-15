import { hilog } from '@kit.PerformanceAnalysisKit';
import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';

export default function abilityTest() {
  describe('ActsAbilityTest', () => {
    beforeAll(() => {
      hilog.info(0x0000, 'TravelMemoryTest', '%{public}s', 'abilityTest begin');
    });
    it('assertServerUrl', 0, () => {
      const serverUrl: string = 'https://top001.xin';
      expect(serverUrl.startsWith('https://')).assertTrue();
      expect(serverUrl.indexOf('top001.xin')).assertLargerOrEqual(0);
    });
  });
}
