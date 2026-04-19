import { describe, it, expect } from '@ohos/hypium'
import RequestPolicy, { PolicyConfig } from '../main/ets/utils/RequestPolicy'

export default function requestPolicyTest() {
  describe('RequestPolicyTest', () => {
    const config: PolicyConfig = {
      studyModeEnabled: true,
      whitelist: ['coursera.org', 'icourse163.org']
    }

    it('shouldAllowWhitelistedMainFrame', 0, () => {
      expect(RequestPolicy.evaluateNavigation('https://www.coursera.org', config).action)
        .assertEqual('allow')
    })

    it('shouldBlockNonWhitelistedMainFrame', 0, () => {
      expect(RequestPolicy.evaluateNavigation('https://github.com', config).action)
        .assertEqual('block')
    })

    it('shouldBlockThirdPartySubResource', 0, () => {
      expect(RequestPolicy.evaluateRequest('https://analytics.example.com/a.js', 'https://www.coursera.org', config, false).action)
        .assertEqual('block')
    })
  })
}
