json.extract! @item, :id, :name, :description, :escalate_to, :unassigned_for, :business_hour_id
json.set! :agent_ids, Array.wrap(params[:api_group][:agent_ids])
json.set! :auto_ticket_assign, @item.auto_ticket_assign if @item.round_robin_enabled?
json.partial! 'shared/utc_date_format', item: @item
