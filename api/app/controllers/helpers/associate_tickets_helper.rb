module AssociateTicketsHelper
  def link_tickets_enabled?
    render_request_error(:require_feature, 403, feature: 'Link Tickets') unless Account.current.link_tkts_enabled?
  end

  def parent_child_tickets_enabled?
    render_request_error(:require_feature, 403, feature: 'Parent Child Tickets') unless Account.current.parent_child_tickets_enabled?
  end

  def feature_enabled?
    link_tickets_enabled? if @item.tracker_ticket? || @item.related_ticket?
    parent_child_tickets_enabled? if @item.assoc_parent_ticket? || @item.child_ticket?
  end

  def parent_ticket
    @parent_ticket ||= current_account.tickets.find_by_display_id(cname_params[:assoc_parent_tkt_id])
  end

  def parent_attachments
    @parent_attachments ||=  if @attachment_ids.present? && parent_ticket.present?
    @parent_ticket.all_attachments.select { |x| @attachment_ids.include?(x.id) }
    else
      []
    end
  end

  def parent_permission
    if cname_params[:assoc_parent_tkt_id].present?
      render_request_error :access_denied, 403 if !parent_ticket || !current_user.has_ticket_permission?(parent_ticket)
    end
  end
end
