class Support::TicketsController < SupportController
  #validates_captcha_of 'Helpdesk::Ticket', :only => [:create]
  helper SupportTicketControllerMethods
  helper AutocompleteHelper
  include SupportTicketControllerMethods 
  include Support::TicketsHelper
  include ExportCsvUtil
  include Helpdesk::Permission::Ticket

  before_filter :validate_params, only: [:create, :update]
  before_filter :check_and_increment_usage, only: [:create]
  
  before_filter :only => [:new, :create] do |c| 
    c.check_portal_scope :anonymous_tickets
  end

  before_filter :clean_params, :only => [:update]
  before_filter :remove_non_editable_fields, :only => [:create, :update]

  skip_before_filter :verify_authenticity_token
  before_filter :verify_authenticity_token, :unless => :public_request?, :except => :check_email
  
  before_filter :require_user, :only => [:show, :index, :filter, :close, :update, :add_people]
  before_filter :load_item, :only => [:show, :update, :close, :add_people]
  before_filter :check_user_permission, :only => [:show], :if => :not_facebook?
  
  # Ticket object loading
  before_filter :build_tickets, :only => [:index, :filter]

  before_filter :verify_ticket_permission, :only => [:show, :update, :close, :add_people]
  before_filter :set_date_filter, :only => [:export_csv]  

  before_filter :check_ticket_permission, :only => [:create]
  before_filter :check_pci_feature_validation, only: [:update]
  skip_before_filter :set_language,:redirect_to_locale, :only => [:check_email]

  def show
    return access_denied unless can_access_support_ticket? && visible_ticket?

    @visible_ticket_fields = current_portal.ticket_fields(:customer_visible, true).reject{ |f| !f.visible_in_view_form? }
    @agent_visible = @visible_ticket_fields.any? { |tf| tf[:field_type] == "default_agent" }
    # @editable_ticket_fields = current_portal.ticket_fields(:customer_editable).reject{ |f| !f.visible_in_view_form? }

    @page_title = "[##{@ticket.display_id}] #{@ticket.subject}"

    respond_to do |format|
      format.html { set_portal_page :ticket_view }
    end
  end
  
  def index    
    @page_title = t("helpdesk.tickets.views.#{@current_filter}") 

    respond_to do |format|
      format.html { set_portal_page :ticket_list }
    end
  end

  def filter
    @page_title = TicketsFilter::CUSTOMER_SELECTOR_NAMES[current_filter.to_sym]

    respond_to do |format|
      format.html { render partial: 'ticket_list' }
      format.js
    end
  end

  def update
    custom_fields = params[:helpdesk_ticket][:custom_field]
    if @item.update_ticket_attributes(params[:helpdesk_ticket])
      token = nil
      respond_to do |format|
        flash[:notice] = t(:'flash.general.update.success', human_name: cname.humanize.downcase)
        token = update_secure_fields(custom_fields) if custom_fields && check_pci_feature
        format.json do
          render json: {
            success: true
          }.merge(token.present? ? { token: token } : {})
        end
      end
    end
  end  

  def configure_export
    @csv_headers = export_fields(true)
    render :layout => false
  end
  
  def export_csv
    params[:wf_per_page] = "100000"
    params[:page] = "1"
    unless params[:a].blank?
      params[:id] = params[:i]
    end
    items = build_tickets
    respond_to do |format|
      format.csv { export_data items, true }
      format.xls { export_xls items, true; headers["Content-Disposition"] = "attachment; filename=\"tickets.xls" }
    end
   end

  def close
    status_id = Helpdesk::Ticketfields::TicketStatus::CLOSED
    if @item.update_attribute(:status , status_id)
     flash[:notice] = I18n.t('ticket_close_success')
    else
     flash[:notice] = I18n.t('ticket_close_failure')
    end
    redirect_to :back
  end

  def add_people
    cc_params = fetch_valid_emails(params[:helpdesk_ticket][:cc_email][:reply_cc])
    if cc_params.length <= TicketConstants::MAX_EMAIL_COUNT
      if current_user.customer?
        new_emails      = separate_new_emails_from_reply_cc(cc_params)
        parsed_emails   = permissible_user_emails(new_emails)
        dropped_emails  = parsed_emails[:dropped_emails]
      end
      @ticket.cc_email[:reply_cc] = (cc_params - dropped_emails.to_s.split(",")).delete_if {|x| !valid_email?(x)}
      update_ticket_cc @ticket.cc_email
      @ticket.trigger_cc_changes(@old_cc_hash)
      @ticket.save
      message = [I18n.t('emails_added_to_cc')]
      message << I18n.t('emails_dropped_message', :emails => h(dropped_emails)) if dropped_emails.present?
      flash[:notice] = message.join("<br/>")
    else
      flash[:error] = "You can add upto #{TicketConstants::MAX_EMAIL_COUNT} CC emails"
    end
    redirect_to support_ticket_path(@ticket)
  end  

  protected 

    def update_secure_fields(custom_fields)
      @secure_field_methods = JWT::SecureFieldMethods.new
      @secure_field_methods.get_jwe_token(custom_fields, @item.id, PciConstants::PORTAL_TYPE[:support_portal]) if @secure_field_methods.secure_fields(custom_fields).present?
    end

    def check_pci_feature_validation
      custom_fields = params[:helpdesk_ticket][:custom_field]
      return if custom_fields.blank?
      @visible_ticket_fields = current_portal.ticket_fields(:customer_visible, true).reject { |f| !f.visible_in_view_form? || f.field_type != TicketFieldsConstants::SECURE_TEXT }
      @visible_ticket_fields.each do |field|
        # if the value is empty it should assign any random value, if not it should be empty string
        custom_fields[field.name] = custom_fields.delete(PciConstants::PREFIX + field.name).present? ? DateTime.now.to_i : '' if custom_fields[PciConstants::PREFIX + field.name]
        if custom_fields[field.name] && !check_pci_feature
          render_request_error :bad_request, 400
          flash[:error] = t(:'flash.general.update.failure', human_name: cname.humanize.downcase)
        end
      end
    end

    def check_pci_feature
      current_account.pci_compliance_field_enabled?
    end

    def cname
      @cname ||= controller_name.singularize
    end

    def load_item
      @ticket = @item = Helpdesk::Ticket.find_by_param(params[:id], current_account) 
      # Using .dup as otherwise it references the same address quoting same values.
      @old_cc_hash = (@ticket and @ticket.cc_email_hash) ? @ticket.cc_email_hash.dup : Helpdesk::Ticket.default_cc_hash
      
      load_archive_ticket unless @ticket 
    end

    def load_archive_ticket
      archive_ticket = Helpdesk::ArchiveTicket.find_by_param(params[:id], current_account)
      raise ActiveRecord::RecordNotFound unless archive_ticket
      redirect_to support_archive_ticket_path(params[:id])
    end

    def redirect_url
      params[:redirect_url].presence || (current_user ? support_ticket_url(@ticket) : root_path(:language => (Language.current.code if current_portal.multilingual?)))
    end
  
    def build_tickets
      if privilege?(:contractor)
        @companies = current_user.companies.sorted
        @requested_by_company = current_requested_by_company
        @requested_company = @companies.find { |c| c.id == @requested_by_company.to_i } if @requested_by_company != 0
      elsif current_user.company_client_manager?
        @company = current_user.company.presence
        @filter_users = current_user.company.users if @company && @company.users.size > 1
      end

      @requested_by = current_requested_by
      @requested_by_user = current_account.users.find_by_id(@requested_by)

      @client_manager_companies = current_user.client_manager_companies.map(&:id)

      date_added_ticket_scope = (params[:start_date].blank? or params[:end_date].blank?) ? 
          ticket_scope : 
          ticket_scope.created_at_inside(params[:start_date], params[:end_date])
      @tickets = TicketsFilter.filter(current_filter, current_user, date_added_ticket_scope)
      filter_helpdesk_tickets_by_product if current_account.launched?(:helpdesk_tickets_by_product)
      per_page = params[:wf_per_page] || 10
      is_correct_order_type = TicketsFilter::SORT_ORDER_FIELDS_BY_KEY.keys.include?(current_wf_order_type)
      current_order = visible_fields.include?(current_wf_order.to_s) && is_correct_order_type  ? "#{current_wf_order} #{current_wf_order_type}" :
        "#{TicketsFilter::DEFAULT_PORTAL_SORT} #{TicketsFilter::DEFAULT_PORTAL_SORT_ORDER}" 
      @tickets = @tickets.order(current_order).paginate(page: params[:page], per_page: per_page)
      @tickets ||= []
    end

    # Used for scoping of filters
    def ticket_scope
      if current_user.contractor? && @companies.present?
        @requested_item = current_account.users.find_by_id(@requested_by) if @requested_by.to_i != 0
        user_id = @requested_by.to_i != 0 ? @requested_by.to_i : nil
        if @requested_by_company.to_i != 0
          company_ids = [@requested_by_company]
          operator = "and"
          user_id = (@client_manager_companies.include?(@requested_by_company.to_i) ? nil : current_user.id) if !user_id
        else
          user_id = current_user.id
          company_ids = @client_manager_companies
          operator = "or"
        end
        current_account.tickets.preload(preload_options).contractor_tickets(user_id, company_ids, operator)
      elsif !current_user.contractor? && current_user.company_client_manager? && @company
        if @requested_by.to_i == 0
          current_user.company.try(:all_tickets) || current_user.tickets
        else
          requested_for = current_account.users.find_by_id(@requested_by)
          @requested_item = requested_for.company_ids.include?(@company.id) ? requested_for : current_user
          user_id = @requested_by.to_i == current_user.id ? @requested_by.to_i : nil
          @requested_item.tickets.preload(preload_options).contractor_tickets(user_id, current_user.company_id, 'or')
        end
      else
        @requested_item = current_user
        @requested_by_company.to_i == 0 ? @requested_item.tickets : 
          @requested_item.tickets.preload(preload_options).contractor_tickets(nil, @requested_by_company.to_i, "or")
      end
    end

    def check_user_permission
      return if current_user and current_user.agent? and !preview? and @item.restricted_in_helpdesk?(current_user)
      
      if current_user and current_user.agent? and !preview?
        return redirect_to helpdesk_ticket_url(:format => params[:format])
      end
    end

    def verify_ticket_permission
      redirect_to safe_send(Helpdesk::ACCESS_DENIED_ROUTE) unless current_user.has_customer_ticket_permission?(@item)
    end

    def not_facebook?
      params[:portal_type] != "facebook"
    end

  private

    def filter_helpdesk_tickets_by_product
      product_id = current_portal.product_id
      join_sql = format("INNER JOIN helpdesk_schema_less_tickets ON
          helpdesk_tickets.account_id = helpdesk_schema_less_tickets.account_id AND
          helpdesk_schema_less_tickets.account_id = %s AND
          helpdesk_tickets.id = helpdesk_schema_less_tickets.ticket_id AND helpdesk_schema_less_tickets.product_id %s",
                        Account.current.id, product_id.present? ? format(' = %s', product_id) : ' IS NULL')
      @tickets = @tickets.joins(join_sql)
    end

    def update_ticket_cc cc_hash
      if cc_hash[:cc_emails].present?
        cc_hash[:cc_emails] = (cc_hash[:cc_emails] + cc_hash[:reply_cc]).uniq
      else
        cc_hash[:cc_emails] = cc_hash[:reply_cc]
      end
    end

    def clean_params
      params[:helpdesk_ticket].keep_if{ |k,v| TicketConstants::SUPPORT_PROTECTED_ATTRIBUTES.exclude? k }
    end

    def public_request?
      current_user.nil?
    end

    def preload_options
      [:ticket_body, :ticket_status, :requester, :responder]
    end

    def separate_new_emails_from_reply_cc cc_emails
      reply_cc = fetch_valid_emails @ticket.cc_email[:reply_cc]
      cc_emails - reply_cc
    end

    def check_ticket_permission
      if (!current_user) || (current_user && current_user.customer?)
        unless can_create_ticket?(params[:helpdesk_ticket][:email])
          flash[:error] = t("helpdesk.tickets.views.invalid_requester")
          set_portal_page :submit_ticket
          render :action => :new
        end
      end
      if params[:cc_emails]        
        params[:cc_emails], dropped_cc_emails = fetch_permissible_cc(current_user, params[:cc_emails], current_account)
        params[:dropped_cc_emails] = dropped_cc_emails.join(",")
      end
    end

    def validate_params
      ticket_type = params['helpdesk_ticket']['ticket_type']
      ticket_field_values = TicketsValidationHelper.ticket_type_values
      if ticket_type.present? && ticket_field_values.exclude?(ticket_type)
         flash[:error] = t('helpdesk.flash.invalid_ticket_type')
         set_portal_page :submit_ticket
         render action: :new
      end
    end
end
