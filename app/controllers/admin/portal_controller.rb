class Admin::PortalController < Admin::AdminController

  before_filter :set_moderation_setting, :only => :update
  before_filter :filter_feature_list, :only => :update

  def index
    @account = current_account
    @forum_moderation = @account.features?(:moderate_all_posts) ? :all : (@account.features?(:moderate_posts_with_links) ? :links : :none) if @account.features?(:forums)
  end

  def update
    current_account.update_attributes!(params[:account])
    current_portal.touch
    flash[:notice] = t(:'flash.portal_settings.update.success')
    redirect_to '/admin/home' #Too much heat.. will think about the better way later. by shan
  end

  protected

  def set_moderation_setting
    return unless current_account.features?(:forums)
    params[:account][:features][:moderate_all_posts] = (params[:moderation] === '2') ? "1" : "0"
    params[:account][:features][:moderate_posts_with_links] = (params[:moderation] === '1') ? "1" : "0"
  end

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
