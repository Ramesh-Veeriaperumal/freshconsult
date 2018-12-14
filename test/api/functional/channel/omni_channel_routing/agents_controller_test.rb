require_relative '../../../test_helper'

  class Channel::OmniChannelRouting::AgentsControllerTest < ActionController::TestCase  
    include OcrHelper
    def test_index
      3.times do
        create_group(Account.current)
      end
      append_header
      get :index, controller_params(version: 'channel/ocr')
      pattern = []
      Account.current.agents.order(:name).all.each do |agent|
        pattern << agent_pattern_for_index_ocr(agent)
      end
      assert_response 200
      match_json({agents: pattern.ordered!})
    end

  end
