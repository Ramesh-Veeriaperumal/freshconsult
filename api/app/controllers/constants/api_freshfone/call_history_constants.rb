module ApiFreshfone::CallHistoryConstants
  EXPORT_FIELDS = %w(requester_id call_type number business_hour_call group_id user_ids start_date end_date company_id export_format).freeze
  CALL_TYPE = %w(received dialed missed voicemail blocked).freeze
  EXPORT_FORMAT = %w(csv excel).freeze

  EXPORT_STATUS_HASH = Hash[*DataExport::EXPORT_STATUS.map { |i| [i[0], i[1]] }.flatten]
  EXPORT_STATUS_STR_HASH = Hash[*DataExport::EXPORT_STATUS.map { |i| [i[1], i[0]] }.flatten]
end.freeze
