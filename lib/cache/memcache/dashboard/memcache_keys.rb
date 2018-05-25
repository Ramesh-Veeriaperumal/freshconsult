module Cache::Memcache::Dashboard::MemcacheKeys

  DASHBOARD_TIMEOUT = 600
  DASHBOARD_REDSHIFT_MY_PERFORMANCE               = "v1/DASHBOARD_REDSHIFT_MY_PERFORMANCE:%{account_id}:%{cache_identifier}:%{user_id}"
  DASHBOARD_REDSHIFT_MY_PERFORMANCE_SUMMARY       = "v1/DASHBOARD_REDSHIFT_MY_PERFORMANCE_SUMMARY:%{account_id}:%{cache_identifier}:%{user_id}"
  DASHBOARD_REDSHIFT_AGENT_PERFORMANCE            = "v1/DASHBOARD_REDSHIFT_AGENT_PERFORMANCE:%{account_id}:%{cache_identifier}"
  DASHBOARD_REDSHIFT_AGENT_PERFORMANCE_SUMMARY    = "v1/DASHBOARD_REDSHIFT_AGENT_PERFORMANCE_SUMMARY:%{account_id}:%{cache_identifier}"
  DASHBOARD_REDSHIFT_GROUP_PERFORMANCE            = "v1/DASHBOARD_REDSHIFT_GROUP_PERFORMANCE:%{account_id}:%{cache_identifier}"
  DASHBOARD_REDSHIFT_GROUP_PERFORMANCE_SUMMARY    = "v1/DASHBOARD_REDSHIFT_GROUP_PERFORMANCE_SUMMARY:%{account_id}:%{cache_identifier}"
  DASHBOARD_REDSHIFT_WORKLOAD                     = "v1/DASHBOARD_REDSHIFT_WORKLOAD:%{account_id}:%{cache_identifier}"
  DASHBOARD_REDSHIFT_WORKLOAD_BY_SOURCE           = "v1/DASHBOARD_REDSHIFT_WORKLOAD_BY_SOURCE:%{account_id}:%{cache_identifier}"
  DASHBOARD_REDSHIFT_TOP_AGENTS                   = "v1/DASHBOARD_REDSHIFT_TOP_AGENTS:%{account_id}:%{cache_identifier}"
  DASHBOARD_REDSHIFT_TOP_CUSTOMERS                = "v1/DASHBOARD_REDSHIFT_TOP_CUSTOMERS:%{account_id}:%{cache_identifier}"

  DASHBOARD_WORKLOAD_GROUPWISE                    = "v1/DASHBOARD_WORKLOAD_GROUPWISE:%{account_id}:%{cache_identifier}:%{workload_name}:%{group_by}"
  DASHBOARD_WORKLOAD                              = "v1/DASHBOARD_WORKLOAD:%{account_id}:%{cache_identifier}:%{workload_name}:%{group_by}"

  DASHBOARD_V2_TRENDS                             = "v1/DASHBOARD_V2_TRENDS:%{account_id}:%{cache_identifier}"
  DASHBOARD_V2_METRICS                            = "v1/DASHBOARD_V2_METRICS:%{account_id}:%{cache_identifier}"

  CUSTOM_DASHBOARD_METRIC                         = "v1/CUSTOM_DASHBOARD_METRIC:%{account_id}:%{cache_identifier}"
end