class Widgets::FeedbackWidgetsController < SupportController

  skip_before_filter :check_privilege
  skip_before_filter :verify_authenticity_token

  skip_before_filter :set_language, :redirect_to_locale
  #Because multilingual is NOT applicable to widgets at the moment

  before_filter :build_item, :only => :new
  before_filter :set_native_mobile, :only => [:create]
  before_filter :check_ticket_permission, :only => [:create]

  include SupportTicketControllerMethods
  include Helpdesk::Permission::Ticket

  def new
    respond_to do |format|
      format.html { setup_form }
      format.json{ render :json => {:fd_status => current_account.subscription.paid_account?}}
    end
  end

  def thanks
    render "thanks"
  end

  def create
    check_captcha = params[:check_captcha] == "true"
    widget_response = {}

    if params[:meta].present?
      params[:meta][:user_agent] = RailsFullSanitizer.sanitize params[:meta][:user_agent] if params[:meta][:user_agent].present?
      params[:meta][:referrer] = sanitize_referrer params[:meta][:referrer] if params[:meta][:referrer].present?
    end

    if create_the_ticket(check_captcha)
      widget_response = {:success => true }
    else
      @feeback_widget_error = true
      decord_params
      setup_form
      widget_response = {:success => false, :error => @ticket.errors.full_messages.first }
    end

    if params[:callback]
      render :json => widget_response.to_json, :callback => params['callback']
    else
      # For IE browsers, we are rendering the json response as text instead of json
      render :text => widget_response.to_json
    end

  end

  def jsonp_create
    check_captcha = params[:check_captcha] == "true"
    # TODO Extract common method
    widget_response = {}

    if params[:meta].present?
      params[:meta][:user_agent] = RailsFullSanitizer.sanitize params[:meta][:user_agent] if params[:meta][:user_agent].present?
      params[:meta][:referrer] = RailsFullSanitizer.sanitize params[:meta][:referrer] if params[:meta][:referrer].present?
    end

    if create_the_ticket(check_captcha)
      widget_response = {:success => true }
    else
      @feeback_widget_error = true
      decord_params
      setup_form
      widget_response = {:success => false, :error => @ticket.errors.full_messages.first }
    end

    if params[:callback]
      render :json => widget_response.to_json, :callback => params['callback']
    else
      render :json => widget_response.to_json
    end
  end

  private

    def build_item
      @ticket = current_account.tickets.new
      @ticket.build_ticket_body
      @ticket.source = Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:feedback_widget]
    end

    def decord_params
      params.merge!(ActiveSupport::JSON.decode params[:retainParams])
    end
    def setup_form
      @widget_form = true
      @ticket_fields = current_portal.customer_editable_ticket_fields
      @ticket_fields_def_pos = ["default_requester", "default_subject", "default_description"]
    end

    def check_ticket_permission
      if (!current_user) || (current_user && current_user.customer?)
        unless can_create_ticket?(params[:helpdesk_ticket][:email])
          render :json => {:success => false, :error => t('admin.widget_config.errors.invalid_requester') }
        end
      end
    end

  def sanitize_referrer(url)
    URI.parse(url.to_s).to_s
  rescue
    nil
  end

end
