require_relative '../../../test_helper'

  class Channel::OmniChannelRouting::GroupsControllerTest < ActionController::TestCase  
    include OcrHelper
    def test_index      
      3.times do
        create_group(@account)
      end
      append_header
      get :index, controller_params(version: 'channel/ocr')
      pattern = []
      Account.current.groups.order(:name).all.each do |group|
        pattern << group_pattern_for_index_ocr(Group.find(group.id))
      end
      assert_response 200
      match_json({groups: pattern.ordered!})
    end

  end
