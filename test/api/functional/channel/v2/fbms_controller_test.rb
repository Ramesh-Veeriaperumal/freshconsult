require_relative '../../../test_helper'
module Channel::V2
  class FbmsControllerTest < ActionController::TestCase
    include ConversationsTestHelper
    include SocialTestHelper
    include UsersTestHelper

    def setup
      super
      @ticket = create_ticket_from_fb_post(true)
      @note = create_fb_note(@ticket)
    end

    def teardown
      super
    end

    def user
      user = @account.users.last || add_new_user(@account)
    end

    def wrap_cname(params)
      { fbm: params }
    end

    def test_update_post_id_successfully
      set_jwt_auth_header('facebook')
      post_id = "#{(Time.now.ago(2.minutes).utc.to_f * 100_000).to_i}_#{(Time.now.ago(6.minutes).utc.to_f * 100_000).to_i}"
      assert_not_equal @note.fb_post.post_id, post_id
      params_hash = { note_id: @note.id, post_id: post_id }
      post :update_post_id, construct_params({ version: 'channel' }, params_hash)
      @note.reload
      assert_equal @note.fb_post.post_id, post_id
      assert_response 200
    end

    def test_update_post_id_without_note_id
      set_jwt_auth_header('facebook')
      post_id = "#{(Time.now.ago(2.minutes).utc.to_f * 100_000).to_i}_#{(Time.now.ago(6.minutes).utc.to_f * 100_000).to_i}"
      params_hash = { post_id: post_id }
      post :update_post_id, construct_params({ version: 'channel' }, params_hash)
      assert_response 403
    end

    def test_update_post_id_without_post_id
      set_jwt_auth_header('facebook')
      params_hash = { note_id: @note.id }
      post :update_post_id, construct_params({ version: 'channel' }, params_hash)
      assert_response 403
    end

  end
end
