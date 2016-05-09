json.set! :id, @item.parent_id
json.extract! @item, :name, :description
json.extract! @meta, :visibility, :category_id
json.set! :company_ids, @meta.customer_ids if @item.company_ids_visible?
json.partial! 'shared/utc_date_format', item: @item
