module Helpdesk::BulkActionMethods

  def sort_items items, group_id
    group_id.present? && Account.current.round_robin_capping_enabled? ?
     items.sort_by{ |item| 
        item.responder_id.to_i 
     } : items
  end
end
