require_relative '../../test_helper'
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
['social_tickets_creation_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
class TwitterMentionsTest < ActiveSupport::TestCase
  include SocialTicketsCreationHelper
  include AccountTestHelper
  include TwitterMentionsTestHelper

  def setup
    super
    account = current_account
  end

  def current_account
    Account.first || create_test_account
  end

  def test_source_additional_info_twitter_handle_destroy_note_update
    handle = create_twitter_handle
    stream = create_mention_stream(handle.id)
    rule = create_smart_filter_rule(stream)
    payload = stream.central_publish_payload.to_json
    payload.must_match_json_expression(mention_stream_publish_pattern(stream))
  end
end
