json.set! :id, @item.parent_id
json.extract! @item, :title, :description, :user_id, :status
json.set! :description_text, @item.desc_un_html
json.set! :type, @meta.art_type
json.set! :category_id, @meta.solution_category_meta.id
json.set! :folder_id, @meta.solution_folder_meta.id
json.extract! @meta, :thumbs_up, :thumbs_down, :hits
json.set! :tags, @item.tags
json.set! :seo_data, @item.seo_data
json.partial! 'shared/utc_date_format', item: @item
