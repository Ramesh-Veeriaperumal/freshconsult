class Admin::PortalController < Admin::AdminController

  before_filter :filter_feature_list, :only => :update

  def index
    @account = current_account
  end
  
  def update
    current_account.update_attributes!(params[:account])
    current_portal.touch
    flash[:notice] = t(:'flash.portal_settings.update.success')
    redirect_to '/admin/home' #Too much heat.. will think about the better way later. by shan
  end

  protected

  # move this method to middleware layer. by Suman
  def filter_feature_list
    allowed_features = {}
    if params[:account] && params[:account][:features]
      filter_features = params[:account][:features]
      Account::ADMIN_CUSTOMER_PORTAL_FEATURES.each do |feature|
        allowed_features[feature] = filter_features[feature] if filter_features[feature]
      end
      params[:account][:features]  = allowed_features
    end
  end

end
