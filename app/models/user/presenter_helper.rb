class User < ActiveRecord::Base
  MARKETPLACE_PROPERTIES = [:name, :job_title, :email, :phone, :mobile, :customer_id, :twitter_id, :address,
                            :time_zone, :language, :description, :deleted, :active, :blocked, :helpdesk_agent,
                            :whitelisted, :fb_profile_id, :user_role].freeze

  def valid_marketplace_event?(action)
    self.is_a?(User) && (action.eql?(:create) || self.tags_updated || self.user_emails_updated || valid_marketplace_changes?)
  end

  private

    def valid_marketplace_changes?
      (self.model_changes || {}).any? { |k, v| MARKETPLACE_PROPERTIES.include?(k.to_sym) || ff_fields.include?(k.to_s) }
    end
end
