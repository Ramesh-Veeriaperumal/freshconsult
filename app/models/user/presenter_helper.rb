class User < ActiveRecord::Base
  APP_PROPERTIES = [:name, :job_title, :email, :phone, :mobile, :twitter_id, :address, :customer_id, :time_zone, :language,
                    :description, :deleted, :active, :blocked, :helpdesk_agent, :whitelisted, :fb_profile_id, :user_role].freeze

  def valid_app_event?(action)
    self.is_a?(User) && !@manual_central_publish && (action.eql?(:create) || self.tags_updated || self.user_emails_updated || valid_app_changes?)
  end

  private

    def valid_app_changes?
      (self.model_changes || {}).any? { |k, v| APP_PROPERTIES.include?(k.to_sym) || ff_fields.include?(k.to_s) }
    end
end
