class ApiEmailConfigsController < ApiApplicationController
  private

    def scoper
      current_account.all_email_configs.reorder(:to_email)
    end
end
