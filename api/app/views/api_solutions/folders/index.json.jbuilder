json.array! @items do |folder|
  json.cache! CacheLib.compound_key(folder, folder.parent, params) do
    json.set! :id, folder.parent_id
    json.extract! folder, :name, :description
    json.extract! folder.parent, :visibility
    json.set! :company_ids, folder.parent.customer_ids if folder.company_ids_visible?
    json.partial! 'shared/utc_date_format', item: folder
  end
end
