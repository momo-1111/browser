import localUnitTest from './LocalUnit.test';
import domainUtilsTest from './DomainUtils.test';
import requestPolicyTest from './RequestPolicy.test';

export default function testsuite() {
  localUnitTest();
  domainUtilsTest();
  requestPolicyTest();
}
