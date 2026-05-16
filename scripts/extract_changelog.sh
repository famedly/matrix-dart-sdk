#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2019-Present Famedly GmbH
#
# SPDX-License-Identifier: AGPL-3.0-or-later

echo "$(awk -v ver=$1 '
          /^(##|###) \[?[0-9]+.[0-9]+.[0-9]+/ {
             if (p) { exit };
             if (index($2, "[")) {
                 split($2, a, "[");
                 split(a[2], a, "]");
                 if (a[1] == ver) {
                     p = 1
                 }
             } else {
                 if ($2 == ver) {
                     p = 1
                 }
             }
         } p
         ' CHANGELOG.md)"