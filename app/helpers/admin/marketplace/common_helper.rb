module Admin::Marketplace::CommonHelper

  include Integrations::ApplicationsHelper
  
  def index_url_params
    {}.tap do |url_params| 
      url_params[:type] = params['type']
      url_params[:category_id] = params['category_id'] if params['category_id']
      url_params[:sort_by] = params['sort_by'] if params['sort_by']
    end.to_query
  end

  def show_url_params
    {}.tap do |url_params| 
      url_params[:type] = params['type']
      url_params[:category_id] = params['category_id'] if params['category_id']
    end.to_query
  end
end