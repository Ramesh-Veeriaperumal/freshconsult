class Support::TicketsController < SupportController
  #validates_captcha_of 'Helpdesk::Ticket', :only => [:create]
  helper SupportTicketControllerMethods
  include SupportTicketControllerMethods 
  include Support::TicketsHelper
  include ExportCsvUtil
  
  before_filter :only => [:new, :create] do |c| 
    c.check_portal_scope :anonymous_tickets
  end

  before_filter :clean_params, :only => [:update]

  before_filter :check_user_permission, :only => [:show], :if => :not_facebook?
  before_filter :require_user, :only => [:show, :index, :filter, :close, :update, :add_people]

  # Ticket object loading
  before_filter :build_tickets, :only => [:index, :filter]
  before_filter :load_item, :verify_ticket_permission, :only => [:show, :update, :close, :add_people]
  before_filter :set_date_filter, :only => [:export_csv]  

  def show
    return access_denied unless can_access_support_ticket? && visible_ticket?

    @visible_ticket_fields = current_portal.ticket_fields(:customer_visible).reject{ |f| !f.visible_in_view_form? }
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
      format.html { render :partial => "ticket_list" }
      format.js
    end
  end

  def update
    if @item.update_ticket_attributes(params[:helpdesk_ticket])
      respond_to do |format|
        format.html { 
          flash[:notice] = t(:'flash.general.update.success', :human_name => cname.humanize.downcase)
          redirect_to support_ticket_path(@item)
        }
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
    csv_hash = params[:export_fields]
    unless params[:a].blank?
      params[:id] = params[:i]
    end
    items = build_tickets
    respond_to do |format|
      format.csv { export_data items, csv_hash, true }
      format.xls { export_xls items, csv_hash, true; headers["Content-Disposition"] = "attachment; filename=\"tickets.xls" }
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
    cc_params = params[:helpdesk_ticket][:cc_email][:cc_emails].split(/,/)
    @ticket.cc_email[:cc_emails] = cc_params.delete_if {|x| !valid_email?(x)}
    @ticket.save
    flash[:notice] = "Email(s) successfully added to CC."
    redirect_to support_ticket_path(@ticket)
  end  

  protected 

    def cname
      @cname ||= controller_name.singularize
    end

    def load_item
      @ticket = @item = Helpdesk::Ticket.find_by_param(params[:id], current_account) 
      @item || raise(ActiveRecord::RecordNotFound)      
    end

    def redirect_url
      params[:redirect_url].presence || (current_user ? support_ticket_url(@ticket) : root_path)
    end
  
    def build_tickets
      @company = current_user.customer.presence
      @filter_users = current_user.customer.users if 
            @company && privilege?(:client_manager) && @company.users.size > 1 

      @requested_by = current_requested_by

      date_added_ticket_scope = (params[:start_date].blank? or params[:end_date].blank?) ? 
          ticket_scope : 
          ticket_scope.created_at_inside(params[:start_date], params[:end_date])
      @tickets = TicketsFilter.filter(current_filter, current_user, date_added_ticket_scope)
      per_page = params[:wf_per_page] || 10
      current_order = visible_fields.include?(current_wf_order.to_s) ? "#{current_wf_order} #{current_wf_order_type}" :
        "#{TicketsFilter::DEFAULT_PORTAL_SORT} #{TicketsFilter::DEFAULT_PORTAL_SORT_ORDER}" 
      @tickets = @tickets.paginate(:page => params[:page], :per_page => per_page, 
          :order => current_order) 
      @tickets ||= []
    end

    def many_employees_in_company?
      privilege?(:client_manager) && has_company? && customer.user > 1
    end

    # Used for scoping of filters
    def ticket_scope
      if privilege?(:client_manager)
        if @requested_by.to_i == 0
          current_user.customer.all_tickets || current_user.tickets
        else
          @requested_item = current_account.users.find_by_id(@requested_by)
          @requested_item.tickets
        end
      else
        @requested_item = current_user
        @requested_item.tickets
      end
    end

    def check_user_permission
      if current_user and current_user.agent? and session[:preview_button].blank?
        return redirect_to helpdesk_ticket_url(:format => params[:format])
      end
    end

    def verify_ticket_permission
      redirect_to send(Helpdesk::ACCESS_DENIED_ROUTE) unless current_user.has_customer_ticket_permission?(@item)
    end

    def not_facebook?
      params[:portal_type] != "facebook"
    end

  private
  
    def clean_params
      params[:helpdesk_ticket].keep_if{ |k,v| TicketConstants::SUPPORT_PROTECTED_ATTRIBUTES.exclude? k }
    end
end