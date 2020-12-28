/*
 *   Famedly Matrix SDK
 *   Copyright (C) 2019, 2020 Famedly GmbH
 *
 *   This program is free software: you can redistribute it and/or modify
 *   it under the terms of the GNU Affero General Public License as
 *   published by the Free Software Foundation, either version 3 of the
 *   License, or (at your option) any later version.
 *
 *   This program is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 *   GNU Affero General Public License for more details.
 *
 *   You should have received a copy of the GNU Affero General Public License
 *   along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

class SupportedVersions {
  List<String> versions;
  Map<String, bool> unstableFeatures;

  SupportedVersions.fromJson(Map<String, dynamic> json) {
    versions = json['versions'].cast<String>();
    unstableFeatures = Map<String, bool>.from(json['unstable_features'] ?? {});
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['versions'] = versions;
    if (unstableFeatures != null) {
      data['unstable_features'] = unstableFeatures;
    }
    return data;
  }
}
