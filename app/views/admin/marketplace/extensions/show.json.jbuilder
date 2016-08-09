json.merge! @extension.except('categories')

json.categories @extension['categories'] do |category|
  json.extract! category, 'name'
  json.url category_url(category)
end

json.back_url admin_marketplace_extensions_path + '?' + index_url_params
json.install_btn install_btn(@extension, @install_status)

if third_party_developer?
  json.policy true
end
