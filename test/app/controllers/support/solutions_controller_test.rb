# frozen_string_literal: true

require_relative '../../../../test/api/test_helper'
class Support::SolutionsControllerTest < ActionController::TestCase
  def test_index
    get :index, id: 'test', portal_type: 'facebook'
    assert_redirected_to '/support/solutions/test'
  end
end
