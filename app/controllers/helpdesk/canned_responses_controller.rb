class Helpdesk::CannedResponsesController < ApplicationController

  before_filter :load_canned_response, :set_mobile, :only => [:show] 
  
  before_filter :load_ticket , :if => :ticket_present?

  def index
    render :partial => "helpdesk/tickets/components/canned_responses"
  end
 
  def show
    if ticket_present?
      render_parsed_content
    else
      render :text => @ca_resp.content_html 
    end
  end

  protected

    def render_parsed_content
      content    = @ca_resp.content_html 
      content    = mobile_content(content) if mobile?
      a_template = Liquid::Template.parse(content).render('ticket' => @ticket, 
                                        'helpdesk_name' => @ticket.account.portal_name)    
      render :text => a_template || ""
    end

    def mobile_content content
      parser = HTMLToTextileParser.new
      parser.feed content
      content = parser.to_textile
    end

    def load_ticket
      @ticket = current_account.tickets.find_by_display_id(params[:id])
    end
    
    def load_canned_response
      @ca_resp = current_account.canned_responses.accessible_for(current_user).
                                                        find_by_id(params[:ca_resp_id])
      render :text => "" and return unless @ca_resp
    end

    def ticket_present?
      !params[:id].blank?
    end
end
