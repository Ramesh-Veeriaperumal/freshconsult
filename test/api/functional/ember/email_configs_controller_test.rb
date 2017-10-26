require_relative '../../test_helper'
class Ember::EmailConfigsControllerTest < ActionController::TestCase
  include EmailConfigsTestHelper

  def wrap_cname(params)
    { email_config: params }
  end

  def test_index
    maxCount = ApiConstants::DEFAULT_PAGINATE_OPTIONS[:max_per_page]
    10.times { create_email_config(active: 'false') }
    maxCount.times { create_email_config(active: 'true') }
    get :index, controller_params(version: 'private')
    assert_response 200
    response = parse_response @response.body
    assert_equal maxCount, response.size
    pattern = []
    Account.current.all_email_configs.reorder(:to_email).where(active: true).limit(maxCount).each do |ec|
      pattern << email_config_pattern(ec)
    end
    match_json(pattern.ordered!)
  end
end
