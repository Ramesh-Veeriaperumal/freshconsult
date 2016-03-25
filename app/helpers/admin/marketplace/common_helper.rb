module Admin::Marketplace::CommonHelper
  
  def index_url_params
    {}.tap do |url_params| 
      url_params[:type] = params['type']
      url_params[:category_id] = params['category_id'] if params['category_id']
    end.to_query
  end

end