require_relative '../test_helper'

class MetalApiConfigurationTest < ActionView::TestCase
  def test_included_modules
    metal_modules = [ActionController::Head, ActionController::Helpers, ActionController::Redirecting,
                     ActionController::Rendering, ActionController::RackDelegation, ActionController::Caching,
                     Rails.application.routes.url_helpers, ActiveSupport::Rescuable, ActionController::MimeResponds,
                     ActionController::ImplicitRender, ActionController::StrongParameters, ActionController::Cookies,
                     ActionController::HttpAuthentication::Basic::ControllerMethods, AbstractController::Callbacks,
                     ActionController::Rescue, ActionController::ParamsWrapper, ActionController::Instrumentation]
    assert (metal_modules - MetalApiConfiguration.included_modules).empty?
  end

  def test_included_view_paths
    assert MetalApiConfiguration.view_paths.paths.collect { |x| x.instance_variable_get('@path') }.include?("#{Rails.root}/api/app/views")
  end

  def test_extended_modules
    assert (class << MetalApiConfiguration; self; end).included_modules.include?(MetalCompatibility)
  end
end
