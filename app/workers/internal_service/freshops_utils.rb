module InternalService::FreshopsUtils
  def invoke_enable_old_ui
    Rails.logger.info('Old UI enable start')
    @account.technicians.find_each do |user|
      begin
        user.make_current
        unless user.text_uc01.try(:[], :agent_preferences).try(:[], :falcon_ui)
          user.merge_preferences = { agent_preferences: { falcon_ui: true } }
          user.save!
        end
      rescue StandardError => e
        Rails.logger.info("Exception invoke_enable_old_ui ::: #{e.inspect} -- #{user.id}")
      end
      User.reset_current_user
    end
    @account.revoke_feature(:disable_old_ui)
    Rails.logger.info("Old UI enabled for account #{@account.full_domain} -- #{@account.id}")
  end
end
