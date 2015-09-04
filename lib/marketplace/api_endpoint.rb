module Marketplace::ApiEndpoint

  ENDPOINTS = [
    # Global API's
    [:mkp_extensions,           "product/%{product_id}/extensions.json", [:type, :category_id]],
    [:all_categories,           "product/%{product_id}/categories.json", []],
    [:extensions_search,        "product/%{product_id}/search.json", [:type, :query, :category_id]],
    [:show_extension,           "product/%{product_id}/extensions/%{version_id}.json", []],
    [:extension_configs,        "product/%{product_id}/extensions/%{version_id}/configurations.json", []],

    # Account API's
    [:indev_extension,          "product/%{product_id}/account/%{account_id}/in_dev_extensions.json", [:type, :category_id]],
    [:indev_extensions_search,  "product/%{product_id}/account/%{account_id}/search.json", [:type, :query, :category_id]],
    [:install_status,           "product/%{product_id}/account/%{account_id}/extensions/%{version_id}/status.json", []],
    [:account_configs,          "product/%{product_id}/account/%{account_id}/extensions/%{version_id}/configurations.json", []],
    [:install_extension,        "product/%{product_id}/account/%{account_id}/install_extension/%{version_id}.json", []],
    [:update_extension,         "product/%{product_id}/account/%{account_id}/extensions/%{version_id}.json", []],
    [:uninstall_extension,      "product/%{product_id}/account/%{account_id}/uninstall_extension/%{version_id}.json", []],
    [:feedbacks,                "product/%{product_id}/account/%{account_id}/extensions/%{version_id}/feedbacks.json", []],
    [:installed_extensions,     "product/%{product_id}/account/%{account_id}/extensions.json", []] 
  ]

  ENDPOINT_URL = Hash[*ENDPOINTS.map { |i| [i[0], i[1]] }.flatten]

  ENDPOINT_PARAMS = ENDPOINTS.map { |i| [i[0], i[2] ] }.to_h
end