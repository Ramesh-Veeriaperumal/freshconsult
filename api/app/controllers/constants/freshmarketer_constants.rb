module FreshmarketerConstants
  LOAD_OBJECT_EXCEPT = %i[enable_integration disable_integration sessions session_info].freeze
  LINK_FIELDS = %i[type value].freeze | ApiConstants::DEFAULT_PARAMS
  SESSIONS_FIELDS = %i[filter].freeze | ApiConstants::DEFAULT_PARAMS
  SESSION_INFO_FIELDS = %i[session_id].freeze | ApiConstants::DEFAULT_PARAMS
end.freeze
