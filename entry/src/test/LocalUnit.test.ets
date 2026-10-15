import { describe, it, expect } from '@ohos/hypium';

/**
 * Host-side unit tests for the small pure helpers used by the web shell.
 */
export default function localUnitTest() {
  describe('localUnitTest', () => {
    it('serverUrlIsHttps', 0, () => {
      const serverUrl: string = 'https://top001.xin';
      expect(serverUrl.startsWith('https://')).assertTrue();
      expect(serverUrl).assertEqual('https://top001.xin');
    });

    it('hostParsing', 0, () => {
      // Mirrors Index.hostOf() so a regression in the parsing rules is caught.
      const hostOf = (url: string): string => {
        const schemeIdx: number = url.indexOf('://');
        if (schemeIdx < 0) {
          return '';
        }
        let rest: string = url.substring(schemeIdx + 3);
        const slash: number = rest.search(/[/?#]/);
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
      };

      expect(hostOf('https://top001.xin/app')).assertEqual('top001.xin');
      expect(hostOf('https://www.top001.xin:443/x')).assertEqual('www.top001.xin');
      expect(hostOf('https://user@top001.xin/x')).assertEqual('top001.xin');
      expect(hostOf('mailto:a@b.com')).assertEqual('');
    });
  });
}
