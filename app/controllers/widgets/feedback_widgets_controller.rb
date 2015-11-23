class Widgets::FeedbackWidgetsController < SupportController

  skip_before_filter :check_privilege
  skip_before_filter :verify_authenticity_token
  skip_before_filter :set_language
  before_filter :build_item, :only => :new
  before_filter :set_native_mobile, :only => [:create]
  include SupportTicketControllerMethods

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
    if create_the_ticket(check_captcha)
      render :json => {:success => true}
    else
      @feeback_widget_error = true
      decord_params
      setup_form
      render :json => {:success => false, :error => @ticket.errors.full_messages.first }
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


end
