/// Support for \[matrix\] native OIDC as extensions on the Matrix Dart SDK.
///
/// Further read: https://areweoidcyet.com/
///
/// This implements the following MSCs:
/// - MSC 3861 - Next-generation auth for Matrix, based on OAuth 2.0/OIDC
///   - MSC 1597 - Better spec for matrix identifiers
///   - MSC 2964 - Usage of OAuth 2.0 authorization code grant and refresh token grant
///   - MSC 2965 - OAuth 2.0 Authorization Server Metadata discovery
///   - MSC 2966 - Usage of OAuth 2.0 Dynamic Client Registration in Matrix
///   - MSC 2967 - API scopes
///   - MSC 3824 - OIDC aware clients
///   - MSC 4191 - Account management deep-linking

library;

export 'msc1597_matrix_identifier_syntax/msc1597_matrix_identifier_syntax.dart';
export 'msc2964_oidc_oauth_grants/msc2964_oidc_oauth_grants.dart';
export 'msc2965_oidc_auth_metadata/msc2965_oidc_auth_metadata.dart';
export 'msc2966_oidc_dynamic_client_registration/msc2966_oidc_dynamic_client_registration.dart';
export 'msc3824_oidc_delegation/msc3824_oidc_delegation.dart';
export 'msc4191_account_management/msc4191_account_management.dart';
