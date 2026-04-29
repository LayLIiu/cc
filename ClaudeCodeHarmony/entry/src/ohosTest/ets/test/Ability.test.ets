import { hilog } from '@kit.PerformanceAnalysisKit';
import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';

export default function abilityTest() {
  describe('ActsAbilityTest', () => {
    it('assertContain', 0, () => {
      const a = 'abc';
      const b = 'b';
      expect(a).assertContain(b);
    });
  });
}
