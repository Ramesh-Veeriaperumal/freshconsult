class Admin::SecurityKeysController < ApiApplicationController
  skip_before_filter :load_object
  before_filter :check_feature

  FEATURE_ACTION_MAPPING = {
    regenerate_widget_key: :help_widget
  }.freeze

  def regenerate_widget_key
    @item = current_account.account_additional_settings
    render_errors(@errors) unless @item.regenerate_help_widget_secret
  end

  private

    def check_feature
      feature_name = FEATURE_ACTION_MAPPING[action_name.to_sym]
      if feature_name.present? && !current_account.safe_send("#{feature_name}_enabled?")
        return render_request_error(:require_feature, 403, feature: feature_name)
      end
    end
end
