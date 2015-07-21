class ApiEmailConfigsController < ApiApplicationController

  private

    def scoper
      current_account.all_email_configs
    end
end
