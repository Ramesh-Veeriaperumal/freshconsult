class TicketsController < ApiApplicationController
  wrap_parameters :ticket, exclude: [], format: [:json, :multipart_form]

  include Helpdesk::TicketActions
  include Helpdesk::TagMethods
  include CloudFilesHelper

  before_filter :assign_protected, only: [:create, :update]
  before_filter :verify_ticket_permission, only: [:update, :show]
  before_filter :ticket_permission?, only: [:destroy, :assign]
  before_filter :restrict_params, only: [:assign, :restore]
  skip_before_filter :load_objects, only: [:index]
  before_filter :validate_filter_params, only: [:index]


  def index
    load_objects tickets_filter(scoper)
  end

  def create
    add_ticket_tags(@tags, @item) if @tags # Tags need to be built if not already available for the account.
    build_normal_attachments(@item, params[cname][:attachments])
    if @item.save_ticket
      render '/tickets/create', location: send("#{nscname}_url", @item.id), status: 201
      notify_cc_people params[cname][:cc_email] unless params[cname][:cc_email].blank?
    else
      render_error(@item.errors)
    end
  end

  def update
    build_normal_attachments(@item, params[cname][:attachments])
    if @item.update_ticket_attributes(params[cname])
      update_tags(@tags, true, @item) if @tags # add tags if update is successful.
    else
      render_error(@item.errors)
    end
  end

  def destroy
    @item.update_attribute(:deleted, true)
    head 204
  end

  def assign
    user = params[cname][:user_id] ? User.find_by_id(params[cname][:user_id]) : current_user
    if user
      @ticket.responder = user
      @ticket.save ? (head 204) : render_error(@item.errors)
    else
      @errors = [BadRequestError.new('responder', "can't be blank")]
      render '/bad_request_error', status: 400
    end
  end

  def restore
    @ticket.update_attribute(:deleted, false)
    head 204
  end

  private

    def paginate_options
      options = super
      options[:order] = order_clause
      options
    end

    def order_clause
      order_by =  params[:order_by] || 'created_at'
      order_type = params[:order_type] || 'desc'
      "helpdesk_tickets.#{order_by} #{order_type} "
    end

    def tickets_filter(tickets)
      tickets = tickets.where(deleted: false, spam: false).api_permissible(current_user)
      @value.each do |key|
        clause = filter_conditions[key.to_sym] || {}
        tickets = tickets.where(clause[:conditions]).joins(clause[:joins])
      end
      tickets
    end

    def filter_conditions
      {
        :spam => {
          :conditions => {:spam => true}
        },
        :deleted => {
          :conditions => {:deleted => true, helpdesk_schema_less_tickets: {boolean_tc02: false}}, 
          :joins => :schema_less_ticket
        },
        :new_and_my_open => {
          :conditions => {:status => 2,  :responder_id => [nil, current_user.id]}
        },
        :monitored_by => {
          :conditions => {helpdesk_subscriptions: {user_id: current_user.id}},
          :joins => :subscriptions
        },
        :requester_id => {
          :conditions => {:requester_id => @requester.try(:id)}
        },
        :company_id => {
          :conditions => {users: {customer_id: @company.try(:id), deleted: false}},
          :joins => :requester
        }
      }
    end

    def check_requester
      @value << :requester_id
      @requester = current_account.users.where(id: params[:requester_id]).first
      @errors << [:requester_id, "can't be blank"] if !@requester
    end

    def check_company
      @value << :company_id
      @company = current_account.companies.find_by_id(params[:company_id])
      @errors << [:company_id, "can't be blank"] if !@company
    end

    def check_filter
      filter = (Array.wrap(params[:filter]) & ApiConstants::TICKET_FILTER).first
      @value << filter
      @errors << ['filter', 'is not included in the list'] unless filter
    end

    def check_sort_params
      @errors << ['order_type', 'is not included in the list'] if 
        params[:order_type] && ApiConstants::TICKET_ORDER_TYPE.exclude?(params[:order_type])
      @errors << ['order_by', 'is not included in the list'] if 
        params[:order_by] && ApiConstants::TICKET_ORDER_BY.exclude?(params[:order_by])
    end

    def validate_filter_params
      params.permit(*ApiConstants::INDEX_TICKET_FIELDS, *ApiConstants::DEFAULT_PARAMS)
      @errors = []
      @value = []
      check_filter if params[:filter]
      check_company if params[:company_id]
      check_requester if params[:requester_id]
      check_sort_params if params[:order_by] || params[:order_type]      
      render_error @errors if @errors.present?
    end

    def scoper
      current_account.tickets
    end

    def restrict_params
      params[cname].permit(*("ApiConstants::#{params[:action].upcase}_TICKET_FIELDS".constantize))
    end

    def manipulate_params
      # Assign cc_emails serialized hash
      cc_emails =  params[cname][:cc_emails] || []
      params[cname][:cc_email] = { cc_emails: cc_emails, fwd_emails: [], reply_cc: cc_emails } unless @item
      # Set manual due by to override sla worker triggerd updates.
      params[cname][:manual_dueby] = true if params[cname][:due_by] && params[cname][:fr_due_by]
      # Collect tags in instance variable as it should not be part of params before build item.
      @tags = params[cname][:tags] if params[cname][:tags]
      # Assign original fields from api params and clean api params.
      assign_and_clean_params(custom_fields: :custom_field, fr_due_by: :frDueBy, type: :ticket_type)
      clean_params([:cc_emails, :tags])
      # build ticket body attributes from description and description_html
      build_ticket_body_attributes
      params[cname][:attachments] = params[cname][:attachments].map { |att| { resource: att } } if params[cname][:attachments]
    end

    def validate_params
      allowed_custom_fields = TicketsValidationHelper.ticket_custom_field_keys(current_account)
      # Should not allow any key value pair inside custom fields hash if no custom fields are available for accnt.
      custom_fields = allowed_custom_fields.empty? ? [nil] : allowed_custom_fields
      field = "ApiConstants::#{action_name.upcase}_TICKET_FIELDS".constantize | ['custom_fields' => custom_fields]
      params[cname].permit(*(field))
      ticket = TicketValidation.new(params[cname], @item, current_account)
      render_error ticket.errors unless ticket.valid?
    end

    def assign_protected
      @item.product ||= current_portal.product
    end

    def verify_ticket_permission
      # Should not allow to update ticket if item is deleted forever or current_user doesn't have permission
      render_request_error :access_denied, 403 unless current_user.has_ticket_permission?(@item) && !@item.trashed
    end

    def ticket_permission?
      # Should allow to delete ticket based on agents ticket permission privileges.
      unless current_user.can_view_all_tickets? || group_ticket_permission?(params[:id]) || assigned_ticket_permission?(params[:id])
        render_request_error :access_denied, 403
      end
    end

    def group_ticket_permission?(ids)
      # Check if current user has group ticket permission and if ticket also belongs to the same group.
      current_user.group_ticket_permission && scoper.group_tickets_permission(current_user, ids).present?
    end

    def assigned_ticket_permission?(ids)
      # Check if current user has restricted ticket permission and if ticket also assigned to the current user.
      current_user.assigned_ticket_permission && scoper.assigned_tickets_permission(current_user, ids).present?
    end

    def build_ticket_body_attributes
      if params[cname][:description] || params[cname][:description_html]
        unless params[cname].has_key?(:ticket_body_attributes)
          ticket_body_hash = {:ticket_body_attributes => { :description => params[cname][:description],
                                  :description_html => params[cname][:description_html] }} 
          params[cname].merge!(ticket_body_hash).tap do |t| 
            t.delete(:description) if t[:description]
            t.delete(:description_html) if t[:description_html]
          end 
        end 
      end
    end

    def load_object
      condition = 'display_id = ? '
      condition += "and deleted = #{ApiConstants::DELETED_SCOPE[action_name]}" if ApiConstants::DELETED_SCOPE.keys.include?(action_name)
      item = scoper.where(condition, params[:id]).first
      @item = instance_variable_set('@' + cname, item)
      head :not_found unless @item
    end
end
