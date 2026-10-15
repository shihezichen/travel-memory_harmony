import { describe, it, expect } from '@ohos/hypium';

export default function abilityTest() {
  describe('abilityTest', () => {
    it('assertServerUrl', 0, () => {
      expect('https://top001.xin').assertEqual('https://top001.xin');
    });
  });
}
