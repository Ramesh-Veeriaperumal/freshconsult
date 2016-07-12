/*
 * Licensed to the Apache Software Foundation (ASF) under one
 * or more contributor license agreements. See the NOTICE file
 * distributed with this work for additional information
 * regarding copyright ownership. The ASF licenses this file
 * to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance
 * with the License. You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied. See the License for the
 * specific language governing permissions and limitations
 * under the License.
 */

namespace rb HelpdeskActivities

enum EventType {
  SYSTEM = 0,
  USER = 1
  ALL = 2
}

 struct TicketDetail {
   1: required i64 account_id,
   2: required string object,
   3: required i64 object_id,
   4: required EventType event_type = EventType.ALL,
   5: required string shard_name,
   6: required string comparator,
   7: optional i64 range_key
 }

struct DashboardDetail {
  1: required i64 account_id,
  2: optional i64 user_id,
  3: optional i64 group_id,
  4: optional i64 requester_id,
  5: optional i64 responder_id,
  6: required EventType event_type = EventType.USER,
  7: required string shard_name
}

struct TicketData {
  1: required i64 actor,
  2: required string event_type,
  3: required i64 published_time,
  4: required i64 account_id,
  5: required string object,
  6: required string object_id,
  7: required string content,
  8: optional string summary,
  9: optional string email_type,
  10: optional string recipient_list,
  11: optional string message_id
}

struct DashboardData {
  1: required i64 account_id,
  2: required i64 notable_id,
  3: required string notable_type,
  4: required i64 user_id,
  5: optional i64 group_id,
  6: optional i64 responder_id,
  7: optional i64 requester_id,
  8: optional string descr,
  9: optional string activity_data
}

struct ActivityData {
  1: required list<TicketData> ticket_data
  2: optional i64 total_count,
  3: optional i64 query_count,
  4: optional string members,
  5: optional string error_message
}

 //Exception class to return message incase of exception
exception ActivityException {
  1: string message
}

exception DashboardException {
  1: string message
}

//Service to be defined by client and server
service TicketActivities { 
    ActivityData get_activities(1: TicketDetail activity_param, 2: i32 limit) throws (1:ActivityException error) 
}

service DashboardActivities {
  list<DashboardData> dashboard_activities(1: DashboardDetail dash_act, 2: i32 limit) throws (1: DashboardException error)
}
