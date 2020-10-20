module ParentChildHelper

  private

  def construct_tkt
    @item.build_flexifield
    ff_def_id = Account.current.flexi_field_defs.first.id
    @item.ff_def = ff_def_id
    if Account.current.id_for_choices_write_enabled?
      @item.ticket_field_data.ff_def = ff_def_id
    end
    build_tkt_body
  end

  def build_tkt_body
    @item.build_ticket_body
    if compose_email?
      @item.status = Helpdesk::Ticketfields::TicketStatus::CLOSED
      source = Helpdesk::Source::OUTBOUND_EMAIL
    else
      source = Helpdesk::Source::PHONE
    end
    @item.source = source
  end

  def compose_email?
    prms = @params || params
    prms[:action].eql?("compose_email") or prms[:template_form].eql?("compose_email")
  end

  def invisible_fields? key
    ["product_id", "responder_id", "source"].include?(key.to_s)
  end

  def recent_templ_ids
    if params[:recent_ids]
      recent_ids = ActiveSupport::JSON.decode(params[:recent_ids])
      recent_ids.compact!
      recent_ids
    end
  end

  def set_assn_types
    @types ||= begin
      association_types = Helpdesk::TicketTemplate::ASSOCIATION_TYPES_KEYS_BY_TOKEN
      is_pc_enabled = current_account.parent_child_tickets_enabled?
      if params[:only_parent] and is_pc_enabled
        [association_types[:parent]]
      elsif params[:prime] and is_pc_enabled
        [association_types[:general], association_types[:parent]]
      else
        [association_types[:general]]
      end
    end
  end

  def set_ticket_association
    assoc_parent_id = @params.nil? ? params[:assoc_parent_id] : @params[:assoc_parent_tkt_id]
    if Account.current.parent_child_tickets_enabled? and assoc_parent_id.present?
      @item.association_type = TicketConstants::TICKET_ASSOCIATION_KEYS_BY_TOKEN[:child]
      @item.assoc_parent_tkt_id = assoc_parent_id
    end
  end

  def can_be_assoc_parent?
    Account.current.parent_child_tickets_enabled? && @assoc_parent_ticket &&
      @assoc_parent_ticket.can_be_associated? && @assoc_parent_ticket.child_tkt_limit_reached?
  end

  def load_assoc_parent
    @assoc_parent_ticket ||= load_by_param(params[:ticket_id] || params[:assoc_parent_id] || params[:id]) if Account.current.parent_child_tickets_enabled?
  end

  def load_parent_template
    @parent_template ||= begin
      acc = @account || current_account
      templ_id = @params.nil? ? params[:parent_templ_id] : @params[:parent_templ_id]
      acc.parent_templates.find_by_id(templ_id) if acc
    end
  end

  def child_template_ids?
    params[:child_ids] && (params[:child_ids] = params[:child_ids].split(',')).present?
  end

  def check_child_limit
    @assoc_parent_ticket.assoc_parent_ticket? and
      ((@assoc_parent_ticket.child_tkts_count + params[:child_ids].count) <=
        TicketConstants::CHILD_TICKETS_PER_ASSOC_PARENT)
  end

  def all_attrs_from_parent
    @item.custom_field = @assoc_parent_ticket.custom_field
    TicketConstants::CHILD_DEFAULT_FD_MAPPING
  end

  def prt_tkt_fd_value key
    if key == "tags"
      @assoc_parent_ticket.tag_names.join(',')
    else
      @assoc_parent_ticket.safe_send(key)
    end
  end
end
