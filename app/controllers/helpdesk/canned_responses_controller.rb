class Helpdesk::CannedResponsesController < ApplicationController

  include HelpdeskAccessMethods
  include Helpdesk::Accessible::ElasticSearchMethods
  before_filter :load_canned_response, :set_mobile, :only => :show
  before_filter :set_native_mobile,:only => [:show,:index]
  before_filter :load_ticket , :if => :ticket_present?

  def index
    respond_to do |format|
      format.html { 
        if redis_key_exists?(COUNT_ESV2_READ_ENABLED)
          ca_folders_response = ca_folders_from_esv2("Admin::CannedResponses::Response", {:size => 300}, default_visiblity)
          parse_esv2_ca_data(ca_folders_response)
        else
          ca_facets = ca_folders_from_es(Admin::CannedResponses::Response, {:size => 300}, default_visiblity)
          process_ca_data(ca_facets)
        end
        #render :partial => "helpdesk/tickets/components/canned_responses"
        render :partial => "helpdesk/tickets/components/ticket_canned_responses"
      }
      format.nmobile {
        @ca_responses = fetch_from_es("Admin::CannedResponses::Response", {:load => Admin::CannedResponses::Response::INCLUDE_ASSOCIATIONS_BY_CLASS, :size => 300}, default_visiblity, "raw_title")
        @ca_responses = accessible_elements(scoper, query_hash('Admin::CannedResponses::Response', 'admin_canned_responses', nil, [:folder])) if @ca_responses.nil?
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
      format.nmobile { render :json => @template_content }
    end
  end

  def recent
    @id_data = ActiveSupport::JSON.decode params[:ids] || []
    @ticket = current_account.tickets.find(params[:ticket_id].to_i) unless params[:ticket_id].blank?
    @ca_responses = fetch_from_es("Admin::CannedResponses::Response", {:load => Admin::CannedResponses::Response::INCLUDE_ASSOCIATIONS_BY_CLASS}, default_visiblity,"raw_title", nil, @id_data)
    @ca_responses = accessible_elements(scoper, query_hash('Admin::CannedResponses::Response', 'admin_canned_responses', ["`admin_canned_responses`.id IN (?)",@id_data])) if @ca_responses.nil?
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
    @ca_responses = fetch_from_es("Admin::CannedResponses::Response", {:load => Admin::CannedResponses::Response::INCLUDE_ASSOCIATIONS_BY_CLASS, :size => 20}, default_visiblity,"raw_title")
    @ca_responses = accessible_elements(scoper, query_hash('Admin::CannedResponses::Response', 'admin_canned_responses', ["`admin_canned_responses`.title like ?","%#{params[:search_string]}%"])) if @ca_responses.nil?
    @ca_responses.blank? ? @ca_responses : @ca_responses.compact!
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
    if ticket_present?
      Liquid::Template.parse(content).render('ticket' => @ticket, 'helpdesk_name' => @ticket.account.portal_name)
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

  def parse_esv2_ca_data response
    begin
      if response.nil?
        fetch_ca_folders_from_db
      else
        folders_list = response["aggregations"]["ca_folders"]["buckets"]
        folder_hash = {}
        folders_list.each do |folder_obj|
          folder_hash[folder_obj["key"]] = folder_obj["doc_count"]
        end
        folder_ids = folder_hash.keys
        @ca_folders = current_account.canned_response_folders.where(id: folder_ids) unless folder_ids.blank?
        @ca_folders.each do |folder|
          folder.visible_responses_count = folder_hash[folder.id]
        end
      end
    rescue Exception => e
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
