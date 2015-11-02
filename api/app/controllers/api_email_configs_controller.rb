class ApiEmailConfigsController < ApiApplicationController
  private

    def scoper
      # Web follows customized order and default order by is name(which is not indexed). Hence falling back to to_emails which is indexed.
      current_account.all_email_configs.reorder(:to_email)
    end
end
