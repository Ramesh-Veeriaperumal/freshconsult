class Helpdesk::CannedResponsesController < ApplicationController

  before_filter :load_canned_response, :set_mobile, :only => :show
  before_filter :set_native_mobile,:only => [:show,:index]
  before_filter :load_ticket , :if => :ticket_present?

  def index
    respond_to do |format|
      format.html { 
        @visible_folders = current_account.canned_response_folders.accessible_for(current_user).all
        render :partial => "helpdesk/tickets/components/canned_responses"
      }
      format.nmobile {
        canned_responses = current_account.canned_responses.accessible_for(current_user).map{ |canned_response| canned_response.to_mob_json }
        render :json => canned_responses
      }
    end
  end

  def show
    render_parsed_content if ticket_present?
    @attachments = @ca_resp.attachments_sharable
    respond_to do |format|
      format.html{ render :partial => '/helpdesk/tickets/components/insert_canned_response.rjs'}
      format.nmobile{ render :json => @a_template }
    end
  end

  def recent
    @id_data = ActiveSupport::JSON.decode params[:ids]
    @ticket = current_account.tickets.find(params[:ticket_id].to_i) unless params[:ticket_id].blank?
    @ca_responses = @id_data.collect {|id| scoper.accessible_for(current_user).find(:all, :conditions => { :id => @id_data }).detect {|resp| resp.id == id}}
    @ca_responses.delete_if { |x| x == nil }
    respond_to do |format|
      format.html
      format.js {
        render :partial => '/helpdesk/tickets/components/recent.rjs'
      }
    end
  end

  def search
    @ticket = current_account.tickets.find(params[:ticket].to_i) unless params[:ticket].blank?
    @ca_responses = scoper.accessible_for(current_user).find(:all,
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
    content = @ca_resp.content_html
    @a_template = Liquid::Template.parse(content).render('ticket' => @ticket,
                                                         'helpdesk_name' => @ticket.account.portal_name)
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
