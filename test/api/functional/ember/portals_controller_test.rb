require_relative '../../test_helper'
['solutions_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
class Ember::PortalsControllerTest < ActionController::TestCase
  include SolutionsHelper
  include PortalsTestHelper

  def wrap_cname(params)
    { solution: params }
  end

  def test_index
    5.times do
      create_portal
    end
    get :index, controller_params(version: 'private')
    pattern = []
    Account.current.portals.all.each do |portal|
      pattern << portal_pattern(portal)
    end
    assert_response 200
    match_json(pattern.ordered!)
  end
end
