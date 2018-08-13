class ApiEmailConfigsController < ApiApplicationController
  private

    def scoper
      # sorting by primary role so that the max_count_const-EMAIL_CONFIG_PER_PAGE emails contain the primary role emails first
      current_account.all_email_configs.reorder('primary_role DESC')
    end
end
