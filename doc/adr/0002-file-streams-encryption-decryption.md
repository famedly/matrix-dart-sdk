# 1. 0001-file-streams-encryption-decryption.md

Date: 2023-08-02

## Status

Accepted

## Context

- Users experience app freezing and crashing while attempting to send large files to each other.
- To ensure secure server uploads, all files must be encrypted using the Matrix protocol.

## Decision

- Files will be encrypted using the AES/CTR/NoPadding algorithm, as specified in the [matrix](https://spec.matrix.org/v1.7/client-server-api/#sending-encrypted-attachments) protocol.
- Implementation of file stream encryption and hashing to prevent app crashes.
- Utilizing the openSSL library for efficient encryption and decryption of file streams and hashing.

## Consequences

- Elimination of app freezes.
- Successful encrypted file uploads to the server.
- Compatibility with other client apps, such as Element, for file decryption.
