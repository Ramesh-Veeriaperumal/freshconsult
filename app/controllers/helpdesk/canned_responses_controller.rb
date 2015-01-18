class Helpdesk::CannedResponsesController < ApplicationController

  include HelpdeskAccessMethods
  before_filter :load_canned_response, :set_mobile, :only => :show
  before_filter :set_native_mobile,:only => [:show,:index]
  before_filter :load_ticket , :if => :ticket_present?

  def index
    @ca_responses = accessible_elements(scoper, query_hash('Admin::CannedResponses::Response', 'admin_canned_responses', nil, [:folder]))
    folders = @ca_responses.map(&:folder)
    @ca_folders = folders.uniq.sort_by{|folder | [folder.folder_type,folder.name]}
    @ca_folders.each do |folder|
      folder.visible_responses_count = folders.count(folder)
    end
    respond_to do |format|
      format.html { 
        render :partial => "helpdesk/tickets/components/canned_responses"
      }
      format.nmobile {
        canned_responses = @ca_responses.map{ |canned_response| canned_response.to_mob_json }
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
    @id_data = ActiveSupport::JSON.decode params[:ids] || []
    @ticket = current_account.tickets.find(params[:ticket_id].to_i) unless params[:ticket_id].blank?
    @ca_responses = accessible_elements(scoper, query_hash('Admin::CannedResponses::Response', 'admin_canned_responses', ["`admin_canned_responses`.id IN (?)",@id_data]))
    respond_to do |format|
      format.html
      format.js {
        render :partial => '/helpdesk/tickets/components/recent.rjs'
      }
    end
  end

  def search
    @ticket = current_account.tickets.find(params[:ticket].to_i) unless params[:ticket].blank?
    @ca_responses = accessible_elements(scoper, query_hash('Admin::CannedResponses::Response', 'admin_canned_responses', ["`admin_canned_responses`.title like ?","%#{params[:search_string]}%"]))
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
    @ca_resp = scoper.find_by_id(params[:ca_resp_id])
    render :text => "" and return unless (@ca_resp and @ca_resp.visible_to_me?)
  end

  def ticket_present?
    !params[:id].blank?
  end
end
