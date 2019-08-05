Authlogic::Session::Base.class_eval do
  
  private

  def secure
    return controller.request.protocol == "https://"
  end

  def httponly
    true
  end
end

Authlogic::ControllerAdapters::RailsAdapter::RailsImplementation.class_eval do
  def self.included(klass)
    # When API and APP requests served from same machine, both application controllers should be checked.
    # It should be verified during gem upgrade. https://github.com/binarylogic/authlogic/blob/v3.4.6/lib/authlogic/controller_adapters/rails_adapter.rb#L30
    # TODO: we should remove ApplicationController after migrated to ApiApplicationController.
    if defined?(::ApplicationController) && defined?(::ApiApplicationController)
      raise AuthlogicLoadedTooLateError, 'Authlogic is trying to prepend a before_filter in ActionController::Base to active itself' \
        ', the problem is that ApplicationController && ApiApplicationController have already been loaded meaning the before_filter won\'t get copied into your' \
        ' application. Generally this is due to another gem or plugin requiring your ApplicationController && ApiApplicationController prematurely, such as' \
        ' the resource_controller plugin. The solution is to require Authlogic before these other gems / plugins. Please require' \
        ' authlogic first to get rid of this error.'
    end

    klass.prepend_before_filter :activate_authlogic
  end
end

require File.dirname(__FILE__) + "/../../fd_password_policy.rb"