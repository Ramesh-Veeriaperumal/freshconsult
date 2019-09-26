module SupportTicketControllerMethods

  include Helpdesk::TicketActions
  
  def show # possible dead code
    @ticket = current_account.tickets.find_by_param(params[:id], current_account)    
    unless can_access_support_ticket?
      access_denied
    else
      respond_to do |format|
        format.html
      end
    end
  end

  def new    
    respond_to do |format|
      format.html { set_portal_page :submit_ticket }
    end
  end
  
  def create
    # The below json is valid for iPhone app version 1.0.0 and Android app update 1.0.3 
    # Once substantial amout of users have upgraded from these version, we need to remove 
    #  1. json format in create method in lib/support_ticket_controller_method.rb
    #  2. is_native_mobile? check in create method in lib/helpdesk/ticket_actions.rb
    if create_the_ticket(feature?(:captcha))
      respond_to do |format|
        format.html {
          flash.keep(:notice)
          flash[:notice] = create_ticket_flash_message
          redirect_to redirect_url
        } 
        format.json {
          render :json => {:success => true}
        }
      end
    else
      logger.debug "Ticket Errors is #{@ticket.errors.inspect}"
      @params = sanitize_params
      set_portal_page :submit_ticket
      render :action => :new
    end
  end
  
  def can_access_support_ticket?
    @ticket && (privilege?(:manage_tickets)  ||  (current_user  &&  ((@ticket.requester_id == current_user.id) || 
                ( current_user.company_client_manager? && current_user.company_ids.include?(@ticket.company_id)) || 
                (current_user.contractor_ticket? @ticket))))
  end

  def visible_ticket?
    !(@ticket.spam || @ticket.deleted)
  end
  
  def show_survey_form
    render :partial => "/support/shared/survey_form" if customer_survey_required?
  end

  def customer_survey_required?
    can_access_support_ticket? && current_user.customer? && current_account && current_account.any_survey_feature_enabled_and_active?  && 
    (@ticket.closed? || @ticket.resolved?)
  end

  def check_email
    items = current_account.user_emails.user_for_email(params[:v])
    respond_to do |format|
      format.json { render :json => { :user_exists => items.present? }  }
    end
  end  

   private
  
    def check_email_scoper # possible dead code
      current_account.all_users
    end

    def create_ticket_flash_message
      if params[:dropped_cc_emails].present?
        message = [I18n.t(:'flash.portal.tickets.create.success_cc_drop')]
        message << h(params[:dropped_cc_emails])
        message.join("<br/>")
      else
        I18n.t(:'flash.portal.tickets.create.success')
      end
    end

    def sanitize_params
      # To avoid reflected xss - we assign sanitized description
      params["helpdesk_ticket"]["ticket_body_attributes"]["description_html"] = @ticket.description_html
    rescue => e
      Rails.logger.error(e)
    ensure
      return params
    end

    def remove_non_editable_fields
      return unless params[:helpdesk_ticket].present?
      field_params = params[:helpdesk_ticket]
      invisible_fields = []
      field_params.keys.each do |key|
        if TicketConstants::NESTED_TICKET_ATTRIBUTES.include?(key)
          field_params[key].delete_if { |key, value| 
            invisible_fields << key unless editable_ticket_fields.include?(key) }
        elsif editable_ticket_fields.exclude?(key)
          invisible_fields << key
          field_params.delete(key)
        end
      end
      Rails.logger.info "invisible_fields for the account :: #{current_account.id} 
        :: #{invisible_fields}" if invisible_fields.present?
    end

    def editable_ticket_fields
      @visible_fields ||= begin
        visible_fields      = current_portal.customer_editable_ticket_fields
        visible_fields_name = visible_fields.map(&:field_name)
        visible_fields.each do |field|
          visible_fields_name << field.nested_levels.map{|lvl| lvl[:name]} if field.nested_field?
        end
        visible_fields_name << TicketConstants::SUPPORT_WHITELISTED_ATTRIBUTES
        visible_fields_name.flatten
      end
    end
end
