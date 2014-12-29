class Admin::PortalController < Admin::AdminController

  before_filter :set_moderators_list, :only => :update
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

  def set_moderators_list
    old_ids = current_account.forum_moderators.map(&:moderator_id)
    new_ids = (params[:forum_moderators] ||= []).map!(&:to_i)
    unique_ids = new_ids & old_ids
    create_moderators(new_ids - unique_ids)
    destroy_moderators(old_ids - unique_ids)
  end

  def create_moderators(create_ids)
    return unless create_ids.present?
    forum_moderators = current_account.technicians.find(create_ids).map do |user|
      current_account.forum_moderators.new(:moderator_id => user.id)
    end
    current_account.forum_moderators += forum_moderators
  end

  def destroy_moderators(destroy_ids)
    return unless destroy_ids.present?
    ForumModerator.destroy_all({ :moderator_id => destroy_ids, :account_id => current_account.id })
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
