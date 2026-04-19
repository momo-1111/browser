import { describe, it, expect } from '@ohos/hypium'
import DomainUtils from '../main/ets/utils/DomainUtils'

export default function domainUtilsTest() {
  describe('DomainUtilsTest', () => {
    it('shouldResolveUrlFromDomainInput', 0, () => {
      expect(DomainUtils.resolveInputToUrl('coursera.org', 'https://cn.bing.com/search?q='))
        .assertEqual('https://coursera.org')
    })

    it('shouldExtractHostFromUrl', 0, () => {
      expect(DomainUtils.tryGetHost('https://www.coursera.org/learn/test') ?? '')
        .assertEqual('www.coursera.org')
    })

    it('shouldMatchSubdomainByRule', 0, () => {
      expect(DomainUtils.isSameDomainOrSubdomain('static.coursera.org', 'coursera.org'))
        .assertEqual(true)
    })
  })
}
