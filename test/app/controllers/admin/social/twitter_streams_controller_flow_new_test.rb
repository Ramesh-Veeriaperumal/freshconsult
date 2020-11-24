# frozen_string_literal: true

require_relative '../../../../../test/api/api_test_helper'
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
['social_tickets_creation_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
class Admin::Social::TwitterStreamsControllerFlowTest < ActionDispatch::IntegrationTest
  include SocialTicketsCreationHelper
  include AccountTestHelper
  include TwitterMentionsTestHelper

  def setup
    super
    @handle = create_twitter_handle
    @stream = create_mention_stream(@handle.id)
  end

  def test_create_twitter_stream
    stream_name = Faker::Lorem.words(1).to_s
    includes = Faker::Lorem.words(1)
    excludes = Faker::Lorem.words(1)
    post '/admin/social/twitter_streams', twitter_stream_create_params(stream_name, includes, excludes)
    new_stream = Social::TwitterStream.find_by_name(stream_name)
    assert_equal includes, new_stream[:includes]
    assert_equal excludes, new_stream[:excludes]
    assert new_stream.custom_stream?
    assert_not_nil new_stream.ticket_rules
    assert_not_nil new_stream.accessible
    assert_response 302
    assert_redirected_to admin_social_streams_url
    assert_equal I18n.t(:'flash.stream.created'), flash[:notice]
  end

  def test_create_invalid_twitter_stream
    Social::TwitterStream.any_instance.stubs(:save).returns(false)
    post '/admin/social/twitter_streams', twitter_stream_create_params
    assert_response 302
    assert_redirected_to admin_social_streams_url
    assert_equal I18n.t(:'flash.stream.create_error'), flash[:notice]
  ensure
    Social::TwitterStream.any_instance.unstub(:save)
  end

  def test_twitter_stream_preview
    includes = Faker::Lorem.words(1)
    excludes = Faker::Lorem.words(1)
    params_hash = {
      includes: includes,
      excludes: excludes,
      exclude_handles: '',
      format: 'json'
    }
    Social::Twitter::Feed.stubs(:fetch_tweets).returns([nil, includes, [], '', '', ''])
    post '/admin/social/twitter_streams/preview', params_hash
    assert_response 200
  ensure
    Social::Twitter::Feed.unstub(:fetch_tweets)
  end

  def test_delete_twitter_stream
    custom_stream = create_new_custom_stream(@handle)
    delete "/admin/social/twitter_streams/#{custom_stream.id}"
    assert_response 302
    assert_equal I18n.t(:'admin.social.flash.stream_deleted', stream_name: custom_stream.name), flash[:notice]
    assert_redirected_to admin_social_streams_url
  end

  def test_update_invalid_twitter_stream_handle
    params_hash = {
      social_twitter_handle: {
        dm_thread_time: '300'
      },
      capture_dm_as_ticket: '0'
    }
    Social::TwitterHandle.any_instance.stubs(:update_attributes).returns(false)
    put "/admin/social/twitter_streams/#{@stream.id}", params_hash
    assert_response 302
    assert_redirected_to "http://localhost.freshpo.com/admin/social/twitter_streams/#{@stream.id}/edit"
    assert_equal I18n.t(:'admin.social.flash.stream_save_error'), flash[:notice]
  ensure
    Social::TwitterHandle.any_instance.unstub(:update_attributes)
  end

  def test_update_invalid_twitter_stream
    params_hash = {
      twitter_stream: {
        name: Faker::Lorem.words(1),
        includes: Faker::Lorem.words(1),
        excludes: Faker::Lorem.words(1),
        filter: '',
        social_id: ''
      },
      visible_to: [Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:all].to_s]
    }
    Social::TwitterStream.any_instance.stubs(:update_attributes).returns(false)
    put "/admin/social/twitter_streams/#{@stream.id}", params_hash
    assert_response 302
    assert_redirected_to "http://localhost.freshpo.com/admin/social/twitter_streams/#{@stream.id}/edit"
    assert_equal I18n.t(:'admin.social.flash.stream_save_error'), flash[:notice]
  ensure
    Social::TwitterStream.any_instance.unstub(:update_attributes)
  end

  def test_new_twitter_stream
    get '/admin/social/twitter_streams/new'
    assert_response 200
  end

  def test_update_custom_stream_with_invalid_rule
    custom_stream = create_new_custom_stream(@handle)
    params_hash = {
      social_ticket_rule: [{
        ticket_rule_id: '',
        deleted: 'false',
        includes: '',
        group_id: '1'
      }, {
        ticket_rule_id: '12',
        deleted: 'true',
        includes: 'test,testing',
        group_id: '1'
      }],
      smart_filter_rule_without_keywords: {
        ticket_rule_id: '',
        group_id: ''
      },
      visible_to: [Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:all].to_s]
    }
    put "/admin/social/twitter_streams/#{custom_stream.id}", params_hash
    assert_response 302
    assert_redirected_to "http://localhost.freshpo.com/admin/social/twitter_streams/#{custom_stream.id}/edit"
    assert_equal I18n.t(:'admin.social.flash.ticket_rule_error'), flash[:notice]
  end

  def test_update_custom_twitter_stream_rule
    custom_stream = create_new_custom_stream(@handle)
    params_hash = {
      social_ticket_rule: [{
        ticket_rule_id: '23',
        deleted: 'false',
        includes: '',
        group_id: '1'
      }],
      mentions: {}
    }
    put "/admin/social/twitter_streams/#{custom_stream.id}", params_hash
    assert_response 302
    assert_redirected_to admin_social_streams_url
  end

  def test_update_custom_stream_with_ticket_rules
    custom_stream = create_new_custom_stream(@handle)
    rule = create_smart_filter_rule(custom_stream)
    params_hash = {
      social_ticket_rule: [{
        ticket_rule_id: rule.id.to_s,
        deleted: 'false',
        includes: 'test,testing',
        group_id: '1'
      }],
      smart_filter_rule_without_keywords: {
        ticket_rule_id: '',
        group_id: ''
      },
      visible_to: [Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:all].to_s]
    }
    Social::TicketRule.any_instance.stubs(:find_by_id).returns(rule)
    put "/admin/social/twitter_streams/#{custom_stream.id}", params_hash
    assert_response 302
    assert_redirected_to admin_social_streams_url
    assert_equal I18n.t(:'admin.social.flash.stream_updated', stream_name: custom_stream.name), flash[:notice]
  ensure
    Social::TicketRule.any_instance.unstub(:find_by_id)
  end

  def test_update_stream_without_capturing_tweet
    params_hash = {
      capture_tweet_as_ticket: '0',
      visible_to: [Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:all].to_s],
      social_ticket_rule: [{
        ticket_rule_id: '12',
        deleted: 'false',
        includes: 'test,testing',
        group_id: '1'
      }]
    }
    put "/admin/social/twitter_streams/#{@stream.id}", params_hash
    assert_response 302
    assert_redirected_to admin_social_streams_url
    assert_equal I18n.t(:'admin.social.flash.stream_updated', stream_name: @stream.name), flash[:notice]
  end

  def test_update_stream_with_small_filter_enabled
    Account.any_instance.stubs(:smart_filter_enabled?).returns(true)
    params_hash = {
      visible_to: [Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:all].to_s],
      social_ticket_rule: [{
        ticket_rule_id: '12',
        deleted: 'false',
        includes: 'test,testing',
        group_id: '1'
      }],
      smart_filter_enabled: '1',
      smart_filter_rule_without_keywords: {
        ticket_rule_id: '',
        group_id: ''
      }
    }
    put "/admin/social/twitter_streams/#{@stream.id}", params_hash
    assert_response 302
    assert_redirected_to admin_social_streams_url
    assert_equal I18n.t(:'admin.social.flash.stream_updated', stream_name: @stream.name), flash[:notice]
  ensure
    Account.any_instance.unstub(:smart_filter_enabled?)
  end

  def test_update_twitter_stream_with_keyword_rules
    params_hash = {
      social_ticket_rule: [{
        ticket_rule_id: '12',
        deleted: 'false',
        includes: '',
        group_id: '1'
      }],
      visible_to: [Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:all].to_s],
      keyword_rules: '1'
    }
    put "/admin/social/twitter_streams/#{@stream.id}", params_hash
    assert_response 302
    assert_redirected_to "http://localhost.freshpo.com/admin/social/twitter_streams/#{@stream.id}/edit"
    assert_equal I18n.t(:'admin.social.flash.empty_rule_error'), flash[:notice]
  end

  def test_update_smart_filter_rule_without_keywords
    rule = create_smart_filter_rule(@stream)
    Account.any_instance.stubs(:smart_filter_enabled?).returns(true)
    params_hash = {
      visible_to: [Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:all].to_s],
      social_ticket_rule: [{
        ticket_rule_id: rule.id.to_s,
        deleted: 'false',
        includes: 'test,testing',
        group_id: '1'
      }],
      smart_filter_enabled: '1',
      smart_filter_rule_without_keywords: {
        ticket_rule_id: '12',
        group_id: ''
      }
    }
    Social::TicketRule.any_instance.stubs(:find_by_id).returns(rule)
    put "/admin/social/twitter_streams/#{@stream.id}", params_hash
    assert_response 302
    assert_redirected_to admin_social_streams_url
    assert_equal I18n.t(:'admin.social.flash.stream_updated', stream_name: @stream.name), flash[:notice]
  ensure
    Account.any_instance.unstub(:smart_filter_enabled?)
    Social::TicketRule.any_instance.unstub(:find_by_id)
  end

  def test_update_default_stream_with_ticket_rules
    rule = create_smart_filter_rule(@stream)
    params_hash = {
      social_ticket_rule: [{
        ticket_rule_id: rule.id.to_s,
        deleted: 'false',
        includes: 'test,testing',
        group_id: '1'
      }],
      smart_filter_rule_without_keywords: {
        ticket_rule_id: '',
        group_id: ''
      },
      visible_to: [Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:all].to_s],
      keyword_rules: '1'
    }
    Social::TwitterStream.any_instance.stubs(:keyword_rules).returns([rule])
    put "/admin/social/twitter_streams/#{@stream.id}", params_hash
    assert_response 302
    assert_redirected_to admin_social_streams_url
    assert_equal I18n.t(:'admin.social.flash.stream_updated', stream_name: @stream.name), flash[:notice]
  ensure
    Social::TwitterStream.any_instance.unstub(:keyword_rules)
  end

  private

    def old_ui?
      true
    end

    def twitter_stream_create_params(stream_name = Faker::Lorem.words(1).to_s, includes = Faker::Lorem.words(1), excludes = Faker::Lorem.words(1))
      {
        twitter_stream: {
          name: stream_name,
          includes: includes,
          excludes: excludes,
          filter: '',
          social_id: ''
        },
        social_twitter_stream: {
          product_id: 'Default product'
        },
        visible_to: [Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:all].to_s],
        social_ticket_rule: [{
          ticket_rule_id: '',
          deleted: 'false',
          includes: 'Ticket Rule Includes',
          group_id: '...'
        }]
      }
    end
end
