/* MIT License
* 
* Copyright (C) 2019, 2020, 2021 Famedly GmbH
* 
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
* 
* The above copyright notice and this permission notice shall be included in all
* copies or substantial portions of the Software.
* 
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
* AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
* OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
* SOFTWARE.
*/

enum EventFormat { client, federation }

class Filter {
  RoomFilter room;
  EventFilter presence;
  EventFilter accountData;
  EventFormat eventFormat;
  List<String> eventFields;

  Filter({
    this.room,
    this.presence,
    this.accountData,
    this.eventFormat,
    this.eventFields,
  });

  Filter.fromJson(Map<String, dynamic> json) {
    room = json['room'] != null ? RoomFilter.fromJson(json['room']) : null;
    presence = json['presence'] != null
        ? EventFilter.fromJson(json['presence'])
        : null;
    accountData = json['account_data'] != null
        ? EventFilter.fromJson(json['account_data'])
        : null;
    eventFormat = json['event_format'] != null
        ? EventFormat.values.firstWhere(
            (e) => e.toString().split('.').last == json['event_format'])
        : null;
    eventFields = json['event_fields'] != null
        ? json['event_fields'].cast<String>()
        : null;
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    if (room != null) {
      data['room'] = room.toJson();
    }
    if (presence != null) {
      data['presence'] = presence.toJson();
    }
    if (eventFormat != null) {
      data['event_format'] = eventFormat.toString().split('.').last;
    }
    if (eventFields != null) {
      data['event_fields'] = eventFields;
    }
    if (accountData != null) {
      data['account_data'] = accountData.toJson();
    }
    return data;
  }
}

class RoomFilter {
  List<String> notRooms;
  List<String> rooms;
  StateFilter ephemeral;
  bool includeLeave;
  StateFilter state;
  StateFilter timeline;
  StateFilter accountData;

  RoomFilter({
    this.notRooms,
    this.rooms,
    this.ephemeral,
    this.includeLeave,
    this.state,
    this.timeline,
    this.accountData,
  });

  RoomFilter.fromJson(Map<String, dynamic> json) {
    notRooms = json['not_rooms']?.cast<String>();
    rooms = json['rooms']?.cast<String>();
    state = json['state'] != null ? StateFilter.fromJson(json['state']) : null;
    includeLeave = json['include_leave'];
    timeline = json['timeline'] != null
        ? StateFilter.fromJson(json['timeline'])
        : null;
    ephemeral = json['ephemeral'] != null
        ? StateFilter.fromJson(json['ephemeral'])
        : null;
    accountData = json['account_data'] != null
        ? StateFilter.fromJson(json['account_data'])
        : null;
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    if (notRooms != null) {
      data['not_rooms'] = notRooms;
    }
    if (rooms != null) {
      data['rooms'] = rooms;
    }
    if (ephemeral != null) {
      data['ephemeral'] = ephemeral.toJson();
    }
    if (includeLeave != null) {
      data['include_leave'] = includeLeave;
    }
    if (state != null) {
      data['state'] = state.toJson();
    }
    if (timeline != null) {
      data['timeline'] = timeline.toJson();
    }
    if (accountData != null) {
      data['account_data'] = accountData.toJson();
    }
    return data;
  }
}

class EventFilter {
  int limit;
  List<String> senders;
  List<String> types;
  List<String> notRooms;
  List<String> notSenders;

  EventFilter(
      {this.limit, this.senders, this.types, this.notRooms, this.notSenders});

  EventFilter.fromJson(Map<String, dynamic> json) {
    limit = json['limit'];
    types = json['senders']?.cast<String>();
    types = json['types']?.cast<String>();
    notRooms = json['not_rooms']?.cast<String>();
    notSenders = json['not_senders']?.cast<String>();
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    if (limit != null) data['limit'] = limit;
    if (types != null) data['types'] = types;
    if (notRooms != null) data['not_rooms'] = notRooms;
    if (notSenders != null) data['not_senders'] = notSenders;
    return data;
  }
}

class StateFilter extends EventFilter {
  List<String> notTypes;
  bool lazyLoadMembers;
  bool includeRedundantMembers;
  bool containsUrl;

  StateFilter({
    this.notTypes,
    this.lazyLoadMembers,
    this.includeRedundantMembers,
    this.containsUrl,
    int limit,
    List<String> senders,
    List<String> types,
    List<String> notRooms,
    List<String> notSenders,
  }) : super(
          limit: limit,
          senders: senders,
          types: types,
          notRooms: notRooms,
          notSenders: notSenders,
        );

  StateFilter.fromJson(Map<String, dynamic> json) : super.fromJson(json) {
    notTypes = json['not_types']?.cast<String>();
    lazyLoadMembers = json['lazy_load_members'];
    includeRedundantMembers = json['include_redundant_members'];
    containsUrl = json['contains_url'];
  }

  @override
  Map<String, dynamic> toJson() {
    final data = super.toJson();
    if (limit != null) {
      data['limit'] = limit;
    }
    if (notTypes != null) {
      data['not_types'] = notTypes;
    }
    if (lazyLoadMembers != null) {
      data['lazy_load_members'] = lazyLoadMembers;
    }
    if (includeRedundantMembers != null) {
      data['include_redundant_members'] = includeRedundantMembers;
    }
    if (containsUrl != null) {
      data['contains_url'] = containsUrl;
    }
    return data;
  }
}
