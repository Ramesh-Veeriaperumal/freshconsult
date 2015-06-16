class Helpdesk::CannedResponsesController < ApplicationController

  include HelpdeskAccessMethods
  include Helpdesk::Accessible::ElasticSearchMethods
  before_filter :load_canned_response, :set_mobile, :only => :show
  before_filter :set_native_mobile,:only => [:show,:index]
  before_filter :load_ticket , :if => :ticket_present?

  def index
    ca_facets = ca_folders_from_es(Admin::CannedResponses::Response, {:size => 300}, default_visiblity)
    process_ca_data(ca_facets)
    
    respond_to do |format|
      format.html { 
        #render :partial => "helpdesk/tickets/components/canned_responses"
        render :partial => "helpdesk/tickets/components/ticket_canned_responses"
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
    @ca_responses = accessible_from_es(Admin::CannedResponses::Response, {:load => Admin::CannedResponses::Response::INCLUDE_ASSOCIATIONS_BY_CLASS}, default_visiblity,"raw_title", nil, @id_data)
    @ca_responses = accessible_elements(scoper, query_hash('Admin::CannedResponses::Response', 'admin_canned_responses', ["`admin_canned_responses`.id IN (?)",@id_data])) if @ca_responses.nil?
    respond_to do |format|
      format.html
      format.js {
        render :partial => '/helpdesk/tickets/components/recent.rjs'
      }
    end
  end

  def search
    @ticket = current_account.tickets.find(params[:ticket].to_i) unless params[:ticket].blank?
    @ca_responses = accessible_from_es(Admin::CannedResponses::Response, {:load => Admin::CannedResponses::Response::INCLUDE_ASSOCIATIONS_BY_CLASS}, default_visiblity,"raw_title")
    @ca_responses = accessible_elements(scoper, query_hash('Admin::CannedResponses::Response', 'admin_canned_responses', ["`admin_canned_responses`.title like ?","%#{params[:search_string]}%"])) if @ca_responses.nil?
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

  def process_ca_data(ca_facets)
    begin
      if ca_facets.try(:[], "ca_folders")
        #Response available in ES
        terms = ca_facets["ca_folders"]["terms"]
        folder_ids = terms.map{ |x| x["term"] }
        @ca_folders = current_account.canned_response_folders.find_all_by_id(folder_ids) unless folder_ids.blank?
        terms.each do |folder|
          @ca_folders.select { |ca_folder| ca_folder.id == folder["term"]}.first.visible_responses_count = folder["count"]
        end
      else
        fetch_ca_folders_from_db
      end
    rescue Exception => e
      #Any ES execption fallback to db
      fetch_ca_folders_from_db
    end
  end

  def fetch_ca_folders_from_db
    #when ES is down or when it throws exception - fallback to DB
    @ca_responses = accessible_elements(scoper, query_hash('Admin::CannedResponses::Response', 'admin_canned_responses', nil, [:folder]))
    folders = @ca_responses.map(&:folder)
    @ca_folders = folders.uniq.sort_by{|folder | [folder.folder_type,folder.name]}
    @ca_folders.each do |folder|
      folder.visible_responses_count = folders.count(folder)
    end
  end
  
end
