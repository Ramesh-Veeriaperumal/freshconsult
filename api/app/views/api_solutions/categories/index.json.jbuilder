json.array! @items do |category|
  json.cache! CacheLib.compound_key(category, category.parent, params) do
    json.set! :id, category.parent.id
    json.extract! category, :name, :description
    json.set! :visible_in, category.parent.portal_ids if category.portal_ids_visible?
    json.partial! 'shared/utc_date_format', item: category
  end
end
