class BootstrapController < ApiApplicationController

  def meta_info
  end

  private

    #overriding this methods from api_application_controller.rb
    def scoper
      current_user
    end

    def load_object(items = scoper)
      # This method has been overridden to avoid pagination.
      @agent = current_user.agent
    end

end