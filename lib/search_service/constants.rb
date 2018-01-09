module SearchService
  module Constants
    QUERY_PATH = 'v1/%{product_name}/%{account_id}/query'.freeze
    TENANTS_PATH = 'v1/%{product_name}/accounts'.freeze
    TENANT_PATH = 'v2/%{product_name}/accounts/%{account_id}'.freeze
    WRITE_PATH = 'v1/%{product_name}/%{account_id}/%{document_name}/%{id}'.freeze
    DELETE_PATH = 'v1/%{product_name}/%{account_id}/%{document_name}/%{id}'.freeze
    MULTI_QUERY_PATH = 'v1/%{product_name}/%{account_id}/multi_query'.freeze
  end.freeze
end.freeze
