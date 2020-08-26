class Helpdesk::CannedResponsesController < ApplicationController

  include HelpdeskAccessMethods
  before_filter :load_canned_response, :set_mobile, :only => :show
  before_filter :set_native_mobile,:only => [:show,:index,:search]
  before_filter :load_ticket , :if => :ticket_present?

  def index
    respond_to do |format|
      format.html { 
        fetch_ca_folders_from_db
        render :partial => "helpdesk/tickets/components/ticket_canned_responses"
      }
      format.nmobile {
        @ca_responses = accessible_elements(scoper, query_hash('Admin::CannedResponses::Response', 'admin_canned_responses', nil, [:folder]))
        canned_responses = @ca_responses.map{ |canned_response| canned_response.to_mob_json }
        render :json => canned_responses
      }
    end

  end

  def show
    @template_content  = render_parsed_content
    @attachments       = @ca_resp.attachments_sharable	
    @allow_attachments = (@ticket.blank? ? true : (@ticket.ecommerce? ? false : true))
    respond_to do |format|
      format.html { render :partial => '/helpdesk/tickets/components/insert_canned_response.rjs'}
      format.nmobile {
        if mobile_canned_response_search_supported?
          render :json => {:template_content => @template_content, :attachments_sharable => @attachments}
        else
          render :json =>  @template_content
        end
        }
    end
  end

  def recent
    @id_data = ActiveSupport::JSON.decode params[:ids] || []
    @ticket = current_account.tickets.find(params[:ticket_id].to_i) unless params[:ticket_id].blank?
    @ca_responses = accessible_elements(scoper, query_hash('Admin::CannedResponses::Response', 'admin_canned_responses', ["`admin_canned_responses`.id IN (?)",@id_data]))
    @ca_responses.blank? ? @ca_responses : @ca_responses.compact!
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
    @ca_responses.blank? ? @ca_responses : @ca_responses.compact!
    respond_to do |format|
      format.html
      format.js {
        render :partial => '/helpdesk/tickets/components/ca_response_search.rjs'
      }
      format.nmobile {
        render :json => @ca_responses.map{ |canned_response| canned_response.to_mob_json_search }
      }
    end
  end

  protected

  def scoper
    current_account.canned_responses
  end

  def render_parsed_content
    content = @ca_resp.content_html
    if ticket_present?
      @ticket.escape_liquid_attributes = true
      Liquid::Template.parse(content).render('ticket' => @ticket.to_liquid, 'helpdesk_name' => @ticket.account.helpdesk_name)
    else
      params[:tkt_cr].present? ? Liquid::Template.parse(content).render('ticket' => nil) : content
    end
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

  def fetch_ca_folders_from_db
    @ca_responses = accessible_elements(scoper, query_hash('Admin::CannedResponses::Response', 'admin_canned_responses', nil, [:folder]))
    folders = @ca_responses.map(&:folder)
    @ca_folders = folders.uniq.sort_by{|folder | [folder.folder_type,folder.name]}
    @ca_folders.each do |folder|
      folder.visible_responses_count = folders.count(folder)
    end
  end
  
end
