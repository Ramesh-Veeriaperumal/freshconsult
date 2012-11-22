class Helpdesk::CannedResponsesController < ApplicationController
  before_filter { |c| c.requires_permission :manage_tickets }

  before_filter :load_canned_response, :set_mobile, :only => :show
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

  def recent
    @id_data = ActiveSupport::JSON.decode params[:ids]
    @ticket = current_account.tickets.find(params[:ticket_id].to_i) unless params[:ticket_id].blank?
    @ca_responses = @id_data.collect {|id| scoper.find(:all, :conditions => { :id => @id_data }).detect {|resp| resp.id == id}}
    respond_to do |format|
      format.html
      format.js { 
        render :partial => '/helpdesk/tickets/components/recent.rjs'
      }
    end
  end

  def search
    @ca_responses = scoper.find(:all, 
      :conditions => ["title like ? ", "%#{params[:search_string]}%"])
    respond_to do |format|
      format.html
      format.js { 
        render :partial => '/helpdesk/tickets/components/ca_response_search.rjs'
      }
    end
  end

  protected

    def scoper
      current_account.canned_responses
    end
    
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
