import 'package:matrix/matrix.dart';

extension LoginFlowOidcDelegationExtention on LoginFlow {
  bool get delegatedOidcCompatibility =>
      // delegated_oidc_compatibility
      additionalProperties['org.matrix.msc3824.delegated_oidc_compatibility'] ==
      true;
}
