require_relative '../test_helper'

class MetalApiControllerTest < ActionController::TestCase
  def test_included_modules
    assert (MetalApiController::METAL_MODULES - MetalApiController.included_modules).empty?
  end

  def test_included_view_paths
    assert controller.view_paths.paths.collect { |x| x.instance_variable_get('@path') }.include?("#{Rails.root}/api/app/views")
  end

  def test_extended_modules
    assert (class << MetalApiController; self; end).included_modules.include?(Compatibility)
  end
end
