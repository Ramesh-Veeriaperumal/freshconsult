class Admin::AdvancedFeaturesController < Admin::AdminController

  before_filter :fetch_advanced_features

  def index
  end

  def toggle
    if @advanced_features_for_acc.include?(params[:feature_name].to_sym)
      toggle_feature
    else
      flash[:error] = I18n.t('admin.advanced_features.not_allowed')
    end
  end

  private

    def fetch_advanced_features
      @advanced_features_for_acc = Account::ADVANCED_FEATURES.select {
        |f| current_account.send("#{f}_toggle_enabled?")
      }
    end

    def toggle_feature
      feature = params[:feature_name]
      current_account.send("#{feature}_enabled?") ? remove_feature(feature) : add_feature(feature)
    end

    def add_feature feature
      current_account.features.send(feature).create
      SAAS::SubscriptionActions.new.add_feature_data([feature])
      flash[:notice] = I18n.t('admin.advanced_features.feature_added')
    end

    def remove_feature feature
      current_account.features.send(feature).destroy
      SAAS::SubscriptionActions.new.drop_feature_data([feature])
      flash[:notice] = I18n.t('admin.advanced_features.feature_removed')
    end

end
