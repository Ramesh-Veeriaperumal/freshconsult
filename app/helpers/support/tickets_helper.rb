module Support::TicketsHelper

  def current_filter
    params[:id] || 'all'
  end

  def current_wf_order 
    cookies[:wf_order] = (params[:wf_order] ? params[:wf_order] : ( (!cookies[:wf_order].blank?) ? cookies[:wf_order] : "due_by" )).to_sym
  end

  def current_wf_order_type 
    cookies[:wf_order_type] = (params[:wf_order_type] ? params[:wf_order_type] : ( (!cookies[:wf_order_type].blank?) ? cookies[:wf_order_type] : "desc" )).to_sym
  end

  def visible_fields
    visible_fields = ["display_id", "status", "created_at", "due_by", "updated_at", "resolved_at"]
    current_portal.ticket_fields(:customer_visible).each { |field| visible_fields.push(field.name) }
    visible_fields
  end  
end
