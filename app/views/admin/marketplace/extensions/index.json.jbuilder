json.search_term params[:query]
json.app_gallery_url admin_marketplace_extensions_path + "?type=#{params['type']}"
json.search_placeholder search_placeholder

json.extensions @extensions do |extension|
  json.merge! extension
  json.url show_admin_marketplace_extensions_path(extension['id']) + '?' + index_url_params
end

json.categories do
  json.array! [{name: t('marketplace.all_categories'), url: admin_marketplace_extensions_path + "?type=#{params['type']}" }]
  json.array! @categories do |category|
    json.(category, 'name')
    json.url category_url(category)
    if category['id'].to_i == params['category_id'].to_i
      json.selected true
    end
  end
end

json.category_name category_name(@categories)
json.search_url search_admin_marketplace_extensions_path + "?type=#{params['type']}"
json.auto_suggest_url auto_suggest_admin_marketplace_extensions_path + "?type=#{params['type']}"
