require_relative '../../../test_helper'

  class Channel::OmniChannelRouting::AgentsGroupsControllerTest < ActionController::TestCase  
    include OcrHelper
    def test_index
      3.times do
        add_test_agent(Account.current)
      end
      append_header
      get :index, controller_params(version: 'channel/ocr')
      pattern = []
      Account.current.agent_groups.all.each do |ag|
        pattern << agents_groups_pattern_for_index_ocr
      end
      assert_response 200
      match_json({agents_groups: pattern.ordered!})
    end

  end
