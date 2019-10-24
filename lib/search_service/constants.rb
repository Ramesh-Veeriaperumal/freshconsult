module SearchService
  module Constants
    QUERY_PATH = 'v1/%{product_name}/%{account_id}/query'.freeze
    TENANTS_PATH = 'v1/%{product_name}/accounts'.freeze
    TENANT_PATH = 'v2/%{product_name}/accounts/%{account_id}'.freeze
    WRITE_PATH = 'v1/%{product_name}/%{account_id}/%{document_name}/%{id}'.freeze
    DELETE_PATH = 'v1/%{product_name}/%{account_id}/%{document_name}/%{id}'.freeze
    MULTI_QUERY_PATH = 'v1/%{product_name}/%{account_id}/multi_query'.freeze
    DELETE_BY_QUERY_PATH = 'v1/%{product_name}/%{account_id}/%{document_name}'.freeze
    MULTI_AGGREGATE_PATH = 'v1/analytics/%{product_name}/%{account_id}/multi_aggregate'.freeze
    AGGREGATE_PATH = 'v1/analytics/%{product_name}/%{account_id}/aggregate'.freeze
    ANALYTICS_QUERY_PATH = 'v1/analytics/%{product_name}/%{account_id}/query'
    ES_TIMEOUT = 17 # need to reduce timeout to 10 or 5 in future based on search performance
  end.freeze
end.freeze
