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
end