module Marketplace::ApiEndpoint

  ENDPOINTS = [
    # Global API's
    #[:name,   "url",   "url params"]
    [:mkp_extensions,           "product/%{product_id}/extensions.json", [:type, :category_id]],
    [:all_categories,           "product/%{product_id}/categories.json", []],
    [:extension_details,        "product/%{product_id}/extensions/%{version_id}.json", []],
    [:extension_configs,        "product/%{product_id}/extensions/%{version_id}/configurations.json", []],
    [:ni_latest_details,        "product/%{product_id}/extensions/latest/%{app_name}.json", []],

    # Account API's
    [:install_status,           "product/%{product_id}/account/%{account_id}/extensions/%{extension_id}/status.json", []],
    [:account_configs,          "product/%{product_id}/account/%{account_id}/extensions/%{version_id}/configurations.json", []],
    [:install_extension,        "product/%{product_id}/account/%{account_id}/extensions/%{extension_id}/%{version_id}.json", []],
    [:update_extension,         "product/%{product_id}/account/%{account_id}/extensions/%{extension_id}/%{version_id}.json", []],
    [:uninstall_extension,      "product/%{product_id}/account/%{account_id}/extensions/%{extension_id}/%{version_id}.json", []],
    [:installed_extensions,     "product/%{product_id}/account/%{account_id}/extensions.json", [:type]] 
  ]

  ENDPOINT_URL = Hash[*ENDPOINTS.map { |i| [i[0], i[1]] }.flatten]

  ENDPOINT_PARAMS = ENDPOINTS.map { |i| [i[0], i[2] ] }.to_h
end