class Support::ArchiveTicketsController < SupportController
  include Support::ArchiveTicketsHelper
  include ExportCsvUtil
  
  around_filter :run_on_slave
  before_filter :check_feature
  skip_before_filter :verify_authenticity_token
  before_filter :verify_authenticity_token, :unless => :public_request?
  
  before_filter :require_user, :only => [:show, :index, :filter]
  before_filter :load_item, :only => [:show]
  before_filter :check_user_permission, :only => [:show], :if => :not_facebook?

  # Ticket object loading
  before_filter :current_filter, :build_tickets, :only => [:index, :filter]
  before_filter :verify_ticket_permission, :only => [:show]
  before_filter :set_date_filter, :only => [:export_csv]  

  def show
    return access_denied unless can_access_support_ticket?

    @visible_ticket_fields = current_portal.ticket_fields(:customer_visible).reject{ |f| !f.visible_in_view_form? }
    
    @agent_visible = @visible_ticket_fields.any? { |tf| tf[:field_type] == "default_agent" }
    # @editable_ticket_fields = current_portal.ticket_fields(:customer_editable).reject{ |f| !f.visible_in_view_form? }

    @page_title = "[##{@ticket.display_id}] #{@ticket.subject}"

    respond_to do |format|
      format.html { set_portal_page :archive_ticket_view }
    end
  end
  
  def index    
    @page_title = t("helpdesk.tickets.views.#{@current_filter}") 

    respond_to do |format|
      format.html { set_portal_page :archive_ticket_list }
    end
  end

  def filter
    @page_title = TicketsFilter::CUSTOMER_SELECTOR_NAMES[current_filter.to_sym]

    respond_to do |format|
      format.html { render :partial => "archive_ticket_list" }
      format.js
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

protected 

    def cname
      @cname ||= controller_name.singularize
    end

    def load_item
      @ticket = @item = Helpdesk::ArchiveTicket.load_by_param(params[:id], current_account) 
      # Using .dup as otherwise it references the same address quoting same values.
      @old_cc_hash = (@ticket and @ticket.cc_email_hash) ? @ticket.cc_email_hash.dup : Helpdesk::Ticket.default_cc_hash
      @item || raise(ActiveRecord::RecordNotFound)      
    end

    def redirect_url
      params[:redirect_url].presence || (current_user ? support_ticket_url(@ticket) : root_path)
    end
  
    def build_tickets
      @company = current_user.company.presence
      @filter_users = current_user.company.users if 
            @company && privilege?(:client_manager) && @company.users.size > 1 

      @requested_by = current_requested_by

      @tickets = (params[:start_date].blank? or params[:end_date].blank?) ? 
          ticket_scope : 
          ticket_scope.created_at_inside(params[:start_date], params[:end_date])
       
      per_page = params[:wf_per_page] || 10
      is_correct_order_type = TicketsFilter::SORT_ORDER_FIELDS_BY_KEY.keys.include?(current_wf_order_type)
      current_order = visible_fields.include?(current_wf_order.to_s) && is_correct_order_type  ? "#{current_wf_order} #{current_wf_order_type}" :
        "#{TicketsFilter::DEFAULT_PORTAL_SORT} #{TicketsFilter::DEFAULT_PORTAL_SORT_ORDER}" 
      
      @tickets = @tickets.paginate(:page => params[:page], :per_page => per_page, 
          :order => current_order) 
      @tickets ||= []
    end

    # Used for scoping of filters
    def ticket_scope
      if privilege?(:client_manager)
        if @requested_by.to_i == 0
          current_user.company.archive_tickets || current_user.archive_tickets
        else
          @requested_item = current_account.users.find_by_id(@requested_by)
          @requested_item.archive_tickets
        end
      else
        @requested_item = current_user
        @requested_item.archive_tickets
      end
    end

    def check_user_permission
      return if current_user and current_user.agent? and !preview? and @item.restricted_in_helpdesk?(current_user)
      
      if current_user and current_user.agent? and !preview?
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
    def can_access_support_ticket?
      @ticket && (privilege?(:manage_tickets)  ||  (current_user  &&  ((@ticket.requester_id == current_user.id) || 
                          ( privilege?(:client_manager) && @ticket.requester.company == current_user.company))))
    end

    def update_reply_cc cc_hash, old_cc_hash
      if cc_hash[:reply_cc]
        removed = cc_hash[:reply_cc] - cc_hash[:cc_emails]
        added = cc_hash[:cc_emails] - old_cc_hash[:cc_emails]
        cc_hash[:reply_cc] = cc_hash[:reply_cc] - removed + added
      else
        cc_hash[:reply_cc] = cc_hash[:cc_emails]
      end
    end

    def public_request?
      current_user.nil?
    end

    def check_feature
      unless current_account.features?(:archive_tickets)
        redirect_to support_tickets_url
      end
    end

    def run_on_slave(&block)
      Sharding.run_on_slave(&block)
    end 
end
