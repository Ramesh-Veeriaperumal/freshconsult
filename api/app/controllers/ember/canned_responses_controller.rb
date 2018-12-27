module Ember
  class CannedResponsesController < CannedResponsesController
    include Helpdesk::Accessible::ElasticSearchMethods

    before_filter :validate_url_params, :load_ticket, only: [:search]
    decorate_views(decorate_objects: [:search])

    def search
      @items = fetch_from_es('Admin::CannedResponses::Response', { load: ::Admin::CannedResponses::Response::INCLUDE_ASSOCIATIONS_BY_CLASS, size: 20 }, default_visiblity, 'raw_title', params[:folder_id]) 
      @items = accessible_elements(scoper, query_hash('Admin::CannedResponses::Response', 'admin_canned_responses', construct_query)) if @items.nil?
      @items.compact! if @items.present?
      render 'index'
    end

    private 

    def construct_query
      query_string = '`admin_canned_responses`.title like ?'
      query_string.concat('AND `admin_canned_responses`.folder_id = ?') if params[:folder_id].present?
      query_items = [query_string , "%#{params[:search_string]}%"]
      query_items << params[:folder_id] if params[:folder_id].present?
      return query_items
    end

  end
end