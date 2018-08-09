module Ember
  class CannedResponsesController < CannedResponsesController
    include Helpdesk::Accessible::ElasticSearchMethods

    before_filter :validate_url_params, :load_ticket, only: [:search]
    decorate_views(decorate_objects: [:search])

    def search
      @items = fetch_from_es('Admin::CannedResponses::Response', { load: ::Admin::CannedResponses::Response::INCLUDE_ASSOCIATIONS_BY_CLASS, size: 20 }, default_visiblity, 'raw_title')
      @items = accessible_elements(scoper, query_hash('Admin::CannedResponses::Response', 'admin_canned_responses', ['`admin_canned_responses`.title like ?', "%#{params[:search_string]}%"])) if @items.nil?
      @items.compact! if @items.present?
      render 'index'
    end
  end
end
