# frozen_string_literal: true

require_relative '../../../../api/test_helper'
class Support::Solutions::FoldersControllerTest < ActionController::TestCase
  def test_show
    get :show, id: 'test', portal_type: 'facebook'
    assert_redirected_to '/support/solutions/folders/test'
  end
end
