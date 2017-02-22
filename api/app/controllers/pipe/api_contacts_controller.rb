module Pipe
  class ApiContactsController < ::ApiContactsController
    include Helpdesk::ToggleEmailNotification

    def create
      begin
        disable_user_activation
        disable_notification
        super
      ensure
        enable_user_activation
        enable_notification
      end
    end

    def update
      begin
        disable_user_activation
        disable_notification
        super
      ensure
        enable_user_activation
        enable_notification
      end
    end
  end
end
