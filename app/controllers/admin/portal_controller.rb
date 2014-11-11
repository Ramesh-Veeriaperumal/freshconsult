class Admin::PortalController < Admin::AdminController

  before_filter :get_moderation_setting, :only => :index
  before_filter :set_moderation_setting, :only => :update
  before_filter :filter_feature_list, :only => :update

  def index
    @account = current_account
  end

  def update
    current_account.update_attributes!(params[:account])
    current_portal.save
    flash[:notice] = t(:'flash.portal_settings.update.success')
    redirect_to '/admin/home' #Too much heat.. will think about the better way later. by shan
  end

  protected

  def set_moderation_setting
    return unless current_account.features?(:forums)
    CommunityConstants::MODERATE.keys.each do |f|
      params[:account][:features][f] = (params[:moderation] === CommunityConstants::MODERATE[f].to_s) ? "1" : "0"
    end
  end

  def get_moderation_setting
    return unless current_account.features_included?(:forums)
    CommunityConstants::MODERATE.keys.each do |f|
      @forum_moderation = f if current_account.features_included?(f)
    end
    @forum_moderation ||= :none
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
