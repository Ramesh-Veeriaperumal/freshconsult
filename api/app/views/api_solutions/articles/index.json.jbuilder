json.array! @items do |article|
  json.cache! CacheLib.compound_key(article, article.parent, params) do
    json.set! :id, article.parent_id
    json.extract! article, :title, :description, :user_id, :status
    json.set! :description_text, article.desc_un_html
    json.set! :type, article.parent.art_type
    json.set! :category_id, article.parent.solution_category_meta.id
    json.set! :folder_id, article.parent.solution_folder_meta.id
    json.set! :seo_data, article.seo_data
    json.partial! 'shared/utc_date_format', item: article
  end

  json.extract! article.parent, :thumbs_up, :thumbs_down, :hits
end
