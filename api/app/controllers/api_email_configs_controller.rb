class ApiEmailConfigsController < ApiApplicationController
  before_filter :load_object, except: [:index, :route_not_found]
  before_filter :load_objects, only: [:index]
  before_filter :load_association, only: [:show]

  private

    def scoper
      current_account.all_email_configs
    end
end
