json.set! :id, @item.parent.id
json.extract! @item, :name, :description
json.set! :visible_in, @meta.portal_ids if @item.portal_ids_visible?
json.partial! 'shared/utc_date_format', item: @item
