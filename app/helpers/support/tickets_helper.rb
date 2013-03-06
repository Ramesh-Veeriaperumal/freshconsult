module Support::TicketsHelper

  TOOLBAR_LINK_OPTIONS = {  "data-remote" => true, 
                            "data-response-type" => "script",
                            "data-loading-box" => "#ticket-list" }  

  def current_filter
    @current_filter ||= set_cookie :wf_filter, "all"
  end

  def current_wf_order 
    @current_wf_order ||= set_cookie :wf_order, "created_at"
  end

  def current_wf_order_type 
    @current_wf_order_type ||= set_cookie :wf_order_type, "desc"
  end

  def current_requested_by
    session[:requested_by] = params[:requested_by].presence || session[:requested_by].presence || 0
  end

  # Will set a cookie until the browser cache is cleared
  def set_cookie type, default_value
    cookies[type] = (params[type] ? params[type] : ( (!cookies[type].blank?) ? cookies[type] : default_value )).to_sym
  end

  def visible_fields
    visible_fields = ["display_id", "status", "created_at", "updated_at"] # removed "due_by", "resolved_at"
    current_portal.ticket_fields(:customer_visible).each { |field| visible_fields.push(field.name) }
    visible_fields
  end

  def visible_fields_details
    current_portal.ticket_fields(:customer_visible)
  end

  def filter_list    
    f_list = [:all, :open_or_pending, :resolved_or_closed].map{ |f| 
                [ t("helpdesk.tickets.views.#{f}"), 
                  filter_support_tickets_path( :wf_filter => f, :requested_by => @requested_by),
                  (@current_filter == f)] }
    # Constructing the dropdown
    dropdown_menu f_list, TOOLBAR_LINK_OPTIONS
  end

  def user_list
    dropdown_menu [
      [t("tickets_filter.everyone_in_company", :company_name => @company.name), 
                    filter_support_tickets_path(:requested_by => 0), 
                    (@requested_by.to_i == 0)],
      [t("myself"), filter_support_tickets_path(:requested_by => current_user.id), 
                    (@requested_by.to_i == current_user.id)],
      [:divider]].concat(@filter_users.map{ 
                    |x| [ x.name, 
                          filter_support_tickets_path(:requested_by => x.id), 
                          (@requested_by.to_i == x.id) ] unless( current_user.id == x.id )
                    }), TOOLBAR_LINK_OPTIONS
  end

  def raised_by
    if @requested_by.to_i == 0
      t("tickets_filter.everyone_in_company", :company_name => @company.name)
    else
      @requested_item.name
    end
  end

  def ticket_sorting
    # Filtering out the visible sorting fields for portal and 
    # preping them for bootstrap dropdown as and array
    vfs = visible_fields
    sort_fields = TicketsFilter::SORT_FIELD_OPTIONS.map { |field|
                      [ field[0], 
                        filter_support_tickets_path(:wf_order => field[1]),
                        (field[1] == @current_wf_order) ] if vfs.include?(field[1].to_s)
                  }.push([:divider]) # Adding a divider that will show up under the sort list

    # Preping the ascending & decending orders for bootstrap dropdown as and array
    sort_order = TicketsFilter::SORT_ORDER_FIELDS_OPTIONS.map{ |so| 
                      [ so[0], 
                        filter_support_tickets_path(:wf_order_type => so[1]), 
                        (so[1] == @current_wf_order_type)] 
                  } 

    # Constructing the dropdown
    dropdown_menu sort_fields.concat(sort_order), TOOLBAR_LINK_OPTIONS
  end

  def ticket_field_display_value(field, ticket)
    _field_type = field.field_type
    _field_value = (field.is_default_field?) ? ticket.send(field.field_name) : ticket.get_ff_value(field.name)
    _dom_type = (_field_type == "default_source") ? "dropdown" : field.dom_type
    case _dom_type
      when "dropdown", "dropdown_blank"
        if(_field_type == "default_agent")
          ticket.responder.name if ticket.responder
        elsif(_field_type == "nested_field")
          ticket.get_ff_value(field.name)
        else
          field.dropdown_selected(((_field_type == "default_status") ? 
              field.all_status_choices : field.choices), _field_value)
        end
    else
      _field_value
    end
  end

end
