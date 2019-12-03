require_relative '../../../../api/test_helper'
class Support::Solutions::ArticlesControllerTest < ActionController::TestCase
  def test_show
    get :show, :id => 'test', :portal_type => 'facebook'
    assert_response 302
  end
end