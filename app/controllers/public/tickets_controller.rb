class Public::TicketsController < ApplicationController

  include SupportTicketControllerMethods
  include Redis::RedisKeys
  include Redis::OthersRedis

  skip_before_filter :check_privilege
  before_filter :check_public_ticket_feature, :load_ticket, :check_scope, :set_selected_tab


  def show
    respond_to do |format|
      format.html
      format.mobile {
          	render :json => @ticket.to_mob_json(true)
        }
    end
	end

  private

  def check_public_ticket_feature
    unless current_account.features_included?(:public_ticket_url) || exists?(GLOBAL_PUBLIC_TICKET_URL_ENABLED)
      flash[:notice] = I18n.t(:'flash.general.access_denied')
      redirect_to send(Helpdesk::ACCESS_DENIED_ROUTE)
    end
  end

   def load_ticket
    schema_less_ticket = current_account.schema_less_tickets.find_by_access_token(params[:id])
    unless schema_less_ticket
      access_denied
    else
      @ticket = schema_less_ticket.ticket
    end
   end

   def check_scope
     redirect_to helpdesk_ticket_url(@ticket, :format => params[:format]) if current_user && current_user.agent?
   end

  def set_selected_tab
    @selected_tab = :checkstatus
  end
end
