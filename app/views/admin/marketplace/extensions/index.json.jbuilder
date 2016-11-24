json.search_term params[:query]
json.app_gallery_url admin_marketplace_extensions_path + '?' + app_gallery_params
json.search_placeholder search_placeholder  

if params[:sort_by]
  @extensions.each do |key, value|
    json.set! "#{key.to_sym}_extensions" do
      json.array!(value) do |extension|
        json.merge! extension
        json.url show_admin_marketplace_extensions_path(extension['id']) + '?' + show_url_params
      end
    end
  end
else
  json.extensions @extensions do |extension|
    json.merge! extension
    json.url show_admin_marketplace_extensions_path(extension['id']) + '?' + show_url_params
  end
end  

json.categories do
  json.array! [{name: t('marketplace.all_apps'), url: admin_marketplace_extensions_path + '?' + app_gallery_params }]
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
json.category_id params['category_id']


