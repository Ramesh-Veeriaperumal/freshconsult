module AssociateTicketsHelper
  def link_tickets_enabled?
    render_request_error(:require_feature, 403, feature: 'Link Tickets') unless Account.current.link_tickets_enabled?
  end

  def parent_child_infra_enabled?
    render_request_error(:require_feature, 403, feature: 'Parent Child Tickets and Field Service Management') unless Account.current.parent_child_infra_enabled?
  end

  def feature_enabled?
    link_tickets_enabled? if @item.tracker_ticket? || @item.related_ticket?
    parent_child_infra_enabled? if @item.assoc_parent_ticket? || @item.child_ticket?
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

  def validate_associated_tickets
    set_all_agent_groups_permission
    if cname_params[:assoc_parent_tkt_id].present?
      check_ticket_permission = Account.current.advanced_ticket_scopes_enabled? ? !current_user.has_read_ticket_permission?(parent_ticket) : !current_user.has_ticket_permission?(parent_ticket)
      render_request_error :access_denied, 403 if !parent_ticket || check_ticket_permission
    elsif cname_params[:related_ticket_ids].present?
      valid_related_tickets = valid_related_tickets(@item.related_ticket_ids)
      if valid_related_tickets.count.zero?
        return render_request_error(:cannot_create_tracker, 400)
      end
      @failed_related_ticket_ids = @item.related_ticket_ids - valid_related_tickets.map(&:display_id)
    end
  end

  def valid_related_tickets(related_ticket_ids)
    tickets = Account.current.tickets.preload(:schema_less_ticket).not_associated.permissible(User.current).where('display_id IN (?)', related_ticket_ids)
    tickets.select(&:can_be_associated?)
  end

  def assign_association_type
    if cname_params[:related_ticket_ids].present?
      @item.association_type = TicketConstants::TICKET_ASSOCIATION_KEYS_BY_TOKEN[:tracker]
    elsif cname_params[:assoc_parent_tkt_id].present? && parent_ticket.present?
      @item.association_type = TicketConstants::TICKET_ASSOCIATION_KEYS_BY_TOKEN[:child]
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
