#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2019-Present Famedly GmbH
#
# SPDX-License-Identifier: AGPL-3.0-or-later

find ./ \( -name "*.dart" -o -name "*.sh" -o -name "*.yaml" -o -name "*.yml" -o -name "*.md" -o -name "*.png" \) -not -path "lib/matrix_api_lite/generated/*" -exec reuse annotate \
    --copyright="Famedly GmbH" \
    --license="AGPL-3.0-or-later" \
    --year="2019-Present" \
    --merge-copyrights \
    {} +