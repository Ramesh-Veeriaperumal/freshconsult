module Marketplace::ApiEndpoint

  ENDPOINTS = [
    # Global API's
    #[:name,   "url",   "url params"]
    [:mkp_extensions,           "product/%{product_id}/extensions.json", [:type, :category_id, :sort_by]],
    [:mkp_custom_apps,          "product/%{product_id}/account/%{account_id}/custom_apps.json", []],
    [:search_mkp_extensions,    "product/%{product_id}/extensions/search.json", [:type, :query]],
    [:auto_suggest_mkp_extensions,"product/%{product_id}/extensions/auto_suggest.json", [:type, :query]],
    [:all_categories,           "product/%{product_id}/categories.json", []],
    [:extension_details,        "product/%{product_id}/extensions/%{extension_id}.json", []],
    [:extension_configs,        "product/%{product_id}/extensions/%{version_id}/configurations.json", []],
    [:ni_latest_details,        "product/%{product_id}/extensions/latest/%{app_name}.json", []],
    [:version_details,          "product/%{product_id}/versions/%{version_id}.json", []],
    [:iframe_settings,          "product/%{product_id}/extensions/%{version_id}/iframe_setting.json", []],
    
    # Account API's
    [:install_status,           "product/%{product_id}/account/%{account_id}/extensions/%{extension_id}/status.json", []],
    [:account_configs,          "product/%{product_id}/account/%{account_id}/extensions/%{version_id}/configurations.json", []],
    [:account_oauth_iparams,    "product/%{product_id}/account/%{account_id}/extensions/%{version_id}/configurations.json?include=oauth_iparams", []],
    [:install_extension,        "product/%{product_id}/account/%{account_id}/extensions/%{extension_id}.json", []],
    [:update_extension,         "product/%{product_id}/account/%{account_id}/extensions/%{extension_id}.json", []],
    [:uninstall_extension,      "product/%{product_id}/account/%{account_id}/extensions/%{extension_id}.json", []],
    [:installed_extension_details, "product/%{product_id}/account/%{account_id}/extensions/%{extension_id}.json", [:installed_version, :version_id]],
    [:installed_extensions,     "product/%{product_id}/account/%{account_id}/extensions.json", [:type]],
    [:app_status,               "product/%{product_id}/account/%{account_id}/installed_extensions/%{installed_extension_id}/app_status.json", []],

    # Marketplace OAuth
    [:oauth_install,            "product/%{product_id}/account/%{account_id}/versions/%{version_id}/oauth_install", []],
    [:fetch_tokens,             'fetch_tokens', []],

    #Helpkit OAuth callback url
    [:oauth_callback,           '/admin/marketplace/installed_extensions/%{extension_id}/%{version_id}/oauth_callback', []]

  ]

  ENDPOINT_URL = Hash[*ENDPOINTS.map { |i| [i[0], i[1]] }.flatten]

  ENDPOINT_PARAMS = ENDPOINTS.map { |i| [i[0], i[2] ] }.to_h
end
