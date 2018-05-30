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

  def modify_ticket_associations
    if unlink?
      cname_params[:tracker_ticket_id] = @item.associates.first
      @item.association_type = nil
    elsif link?
      @item.association_type = TicketConstants::TICKET_ASSOCIATION_KEYS_BY_TOKEN[:related]
    end
  end

  def link_or_unlink?
    cname_params.key?(:tracker_ticket_id)
  end

  def link?
    cname_params[:tracker_ticket_id].present?
  end

  def unlink?
    [:tracker_id, :tracker_ticket_id].any? { |tracker_param| cname_params.key?(tracker_param) && cname_params[tracker_param].nil? }
  end
end
