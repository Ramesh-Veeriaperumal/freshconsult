require_relative '../../api/unit_test_helper'
['social_tickets_creation_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }

class FacebookAdPostsTest < ActiveSupport::TestCase
  include SocialTicketsCreationHelper

  def setup
    Account.stubs(:current).returns(Account.first || create_test_account)
  end

  def teardown
    Account.unstub(:current)
    super
  end

  def test_facebook_ad_central_publish_payload
    fb_page = create_fb_page(true)
    create_ad_post_ticket_rule(fb_page.facebook_streams)
    payload = @final_stream.central_publish_payload.to_json
    payload.must_match_json_expression(ad_post_stream_publish_pattern(@final_stream))
  end

  def test_facebook_ad_central_publish_payload_with_update
    fb_page = create_fb_page(true)
    create_ad_post_ticket_rule(fb_page.facebook_streams)
    payload = @final_stream.central_publish_payload.to_json
    payload.must_match_json_expression(ad_post_stream_publish_pattern(@final_stream))
    update_ad_post_ticket_rule
    assert_equal 1, @final_stream.model_changes_for_central['rules'][1][0]['action']['group_id']
    assert_equal 1, @final_stream.model_changes_for_central['rules'][1][0]['action']['product_id']
  end

  def test_plan_downgrade_feature_removal
    Account.current.add_feature(:fb_ad_posts)
    fb_page = create_fb_page(true)
    create_ad_post_ticket_rule(fb_page.facebook_streams)
    assert_equal(true, Account.current.has_feature?(:fb_ad_posts))
    assert_equal(true, @final_stream.facebook_ticket_rules.first.present?)
    SAAS::AccountDataCleanup.new(Account.current, ['fb_ad_posts']).perform_cleanup
    assert_equal(false, Account.current.has_feature?(:fb_ad_posts))
    assert_equal(nil, @final_stream.facebook_ticket_rules.first)
  end

  def test_remove_ad_post_rule
    fb_page = create_fb_page(true)
    create_ad_post_ticket_rule(fb_page.facebook_streams)
    assert fb_page.ad_post_stream.facebook_ticket_rules.count != 0
    fb_page.ad_post_stream.delete_rules
    assert_equal 0, fb_page.ad_post_stream.facebook_ticket_rules.count
  end

  def create_ad_post_ticket_rule(streams)
    streams.each do |stream|
      @final_stream = stream if stream.ad_stream?
    end
    rule = FactoryGirl.build(:seed_social_filter_rules)
    rule.account_id = Account.current.id
    rule.stream_id = @final_stream.id
    rule.save
  end

  def update_ad_post_ticket_rule
    @final_stream.facebook_ticket_rules.first.attributes = { action_data: { group_id: 1, product_id: 1 } }
    @final_stream.save!
  end

  def ad_post_stream_publish_pattern(stream)
    {
      account_id: Account.current.id,
      created_at: stream.created_at.try(:utc).try(:iso8601),
      updated_at: stream.updated_at.try(:utc).try(:iso8601),
      type: 'ad_post',
      rules: stream.rules,
      id: stream.id
    }
  end
end
