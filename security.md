# Security Policy

## Coordinated Vulnerability Disclosure

Thank you for helping keep Famedly’s systems and users safe. We appreciate responsible security research and coordinated vulnerability disclosure.

This policy is published by Famedly GmbH at [famedly.com/security](https://famedly.com/security) and constitutes authorisation to perform proportionate security testing solely for the purpose of identifying and reporting security vulnerabilities, provided the testing is conducted in accordance with this policy.

If you believe you have identified a security vulnerability in a Famedly system, product, or repository, report it through one of the following channels:

- Email: security@famedly.com
- GitHub: Use the Security → Report a vulnerability feature for public repositories, where available

Do not disclose the issue publicly or share details with third parties before coordinated disclosure has been completed.

## Reporting Requirements

Reports must include:

- A clear description of the vulnerability and its security impact
- The affected product, service, repository, or component
- Reproduction steps or a proof of concept, where applicable
- Preconditions or assumptions required to exploit the issue

Reports must demonstrate a concrete and realistic security impact. Findings that only identify missing controls, configuration deviations, or best-practice recommendations without an exploitable weakness are not considered valid vulnerability reports.

Out-of-scope, insufficient, or duplicate reports may be closed without further action.

## Ground Rules for Researchers

While investigating and reporting vulnerabilities, researchers must act in good faith and minimise impact.

Testing must be limited to what is reasonably necessary to identify and demonstrate the security issue. The purpose of this policy is not to permit intentional access to or processing of data, including personal data. Any such access may occur only incidentally and solely to the extent required to demonstrate the vulnerability.

Researchers must:

- Avoid unnecessary access to systems, services, data, or accounts
- Not intentionally access, modify, or delete data beyond what is required to demonstrate the issue
- Limit testing to the minimum scope necessary and stop once the vulnerability has been confirmed
- Treat all information obtained during testing as confidential and not share it with third parties

Any data, including personal data, accessed incidentally during testing must not be retained longer than necessary and must be securely deleted once the vulnerability has been demonstrated.

## Scope

### In Scope

Security vulnerabilities in Famedly-owned applications, libraries, services, APIs, and infrastructure that meaningfully affect confidentiality, integrity, authentication, or authorization.

If there is uncertainty about whether a system or service is in scope, reporters should contact Famedly for clarification before starting testing.

### Out of Scope

The following are not considered security vulnerabilities on their own:

- Missing or non-optimal security controls or configurations without a demonstrated exploit or security impact (for example missing HTTP security headers)
- Findings based solely on automated scanners, linters, or compliance tools
- Security best-practice or compliance issues without a vulnerability
- Denial-of-service (DoS / DDoS) attacks
- Social engineering or phishing attacks
- Physical security issues
- Attacks requiring compromised client devices or user accounts
- Vulnerabilities in third-party services not operated by Famedly

We reserve the right to determine whether a report is in scope.

## Our Commitments

For reports that meet this policy, we commit to:

- Acknowledge receipt in a timely manner
- Provide status updates during investigation
- Work toward remediation as quickly as reasonably possible
- Coordinate disclosure timelines with the reporter

Unless otherwise agreed, we aim to complete remediation and coordinated disclosure within 90 days of the initial report.

## Legal Safe Harbor

If you act in good faith and in accordance with this policy, Famedly will not pursue civil or criminal action against you for activities that are reasonably necessary to identify and report a security vulnerability.

This does not apply to malicious, reckless, or out-of-scope activity.

## Attribution and Rewards

Please indicate whether you would like public attribution. If no preference is stated, no attribution will be made.

Famedly does not operate a bug bounty or financial reward program.

## Language

This policy is published in English. Vulnerability reports may be submitted in English or German.

