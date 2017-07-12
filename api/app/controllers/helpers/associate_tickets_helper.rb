module AssociateTicketsHelper
  def link_tickets_enabled?
    render_request_error(:require_feature, 403, feature: 'Link Tickets') unless Account.current.link_tkts_enabled?
  end

  def parent_child_tickets_enabled?
    render_request_error(:require_feature, 403, feature: 'Parent Child Tickets') unless Account.current.parent_child_tkts_enabled?
  end

  def feature_enabled?
    link_tickets_enabled? if @item.tracker_ticket? || @item.related_ticket?
    parent_child_tickets_enabled? if @item.assoc_parent_ticket? || @item.child_ticket?
  end
end
