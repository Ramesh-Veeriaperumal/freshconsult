module Pipe
  class ApiContactsController < ::ApiContactsController
    include Helpdesk::ToggleEmailNotification

    def create
      disable_user_activation
      disable_notification
      super
    ensure
      enable_user_activation
      enable_notification
    end

    def update
      disable_user_activation
      disable_notification
      super
    ensure
      enable_user_activation
      enable_notification
    end
  end
end
