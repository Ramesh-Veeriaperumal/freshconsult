require_relative '../../test_helper'
['dynamo_helper.rb', 'social_tickets_creation_helper.rb', 'twitter_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }

class SocialDynamoMethodsTest < ActionView::TestCase
  include DynamoHelper
  include SocialTicketsCreationHelper
  include TwitterHelper
  include Social::Constants

  TABLE = TABLE_NAME['interactions']
  SCHEMA = TABLES[TABLE][:schema]

  def test_dynamo_helper_insert_query_updates_record_when_already_present
    Aws::DynamoDB::Client.any_instance.stubs(:put_item).raises(Aws::DynamoDB::Errors::ConditionalCheckFailedException.new(Faker::Lorem.word, Faker::Lorem.word))
    Social::DynamoHelper.stubs(:update).returns(true)
    assert_nothing_raised do
      assert Social::DynamoHelper.insert(Faker::Lorem.word, { stream_id: '1', feed_id: '1' }, SCHEMA)
    end
  ensure
    Aws::DynamoDB::Client.any_instance.unstub(:put_item)
    Social::DynamoHelper.unstub(:update)
  end

  def test_dynamo_helper_should_delete_existing_item
    Aws::DynamoDB::Client.any_instance.stubs(:delete_item).returns(true)
    assert_nothing_raised do
      assert Social::DynamoHelper.delete_item(Faker::Lorem.word, { hash_key: '1', range_key: '1' }, SCHEMA)
    end
  ensure
    Aws::DynamoDB::Client.any_instance.unstub(:delete_item)
  end

  def test_dynamo_helper_should_get_item_without_errors
    Aws::DynamoDB::Client.any_instance.stubs(:get_item).returns(true)
    assert_nothing_raised do
      assert Social::DynamoHelper.get_item(Faker::Lorem.word, '1', '1', SCHEMA, ['feed_ids'])
    end
  ensure
    Aws::DynamoDB::Client.any_instance.unstub(:get_item)
  end

  def test_dynamo_helper_should_rescue_validation_exception
    Aws::DynamoDB::Client.any_instance.stubs(:describe_table).raises(Aws::DynamoDB::Errors::ValidationException.new(Faker::Lorem.word, Faker::Lorem.word))
    assert_nothing_raised do
      refute Social::DynamoHelper.table_exists?(Faker::Lorem.word)
    end
  ensure
    Aws::DynamoDB::Client.any_instance.unstub(:describe_table)
  end

  def test_dynamo_helper_should_rescue_resource_not_found_exception
    Aws::DynamoDB::Client.any_instance.stubs(:describe_table).raises(Aws::DynamoDB::Errors::ResourceNotFoundException.new(Faker::Lorem.word, Faker::Lorem.word))
    assert_nothing_raised do
      refute Social::DynamoHelper.table_exists?(Faker::Lorem.word)
    end
  ensure
    Aws::DynamoDB::Client.any_instance.unstub(:describe_table)
  end

  def test_dynamo_helper_should_rescue_service_error
    Aws::DynamoDB::Client.any_instance.stubs(:describe_table).raises(Aws::DynamoDB::Errors::ServiceError.new(Faker::Lorem.word, Faker::Lorem.word))
    assert_nothing_raised do
      refute Social::DynamoHelper.table_exists?(Faker::Lorem.word)
    end
  ensure
    Aws::DynamoDB::Client.any_instance.unstub(:describe_table)
  end

  def test_dynamo_helper_should_rescue_timeout_error
    Aws::DynamoDB::Client.any_instance.stubs(:describe_table).raises(Timeout::Error)
    assert_nothing_raised do
      refute Social::DynamoHelper.table_exists?(Faker::Lorem.word)
    end
  ensure
    Aws::DynamoDB::Client.any_instance.unstub(:describe_table)
  end

  def test_dynamo_helper_should_wait_for_resource_to_complete
    describe_table_responses = [{ table: { table_status: 'DELETING' } }, { table: { table_status: 'DELETED' } }]
    Social::DynamoHelper.stubs(:table_exists?).returns(true)
    Aws::DynamoDB::Client.any_instance.stubs(:describe_table).returns(describe_table_responses.first, describe_table_responses.last)
    assert_nothing_raised do
      Social::DynamoHelper.delete_table(Faker::Lorem.word)
    end
  ensure
    Social::DynamoHelper.unstub(:table_exists?)
    Aws::DynamoDB::Client.any_instance.unstub(:describe_table)
  end

  def test_dynamo_base_feed_should_convert_numeric_key_values_to_integer
    feed_base = Social::Dynamo::Feed::Base.new
    modified_item = feed_base.feeds_hash(Faker::Lorem.word, Faker::Lorem.word, nil, 1, 1, { likes: '20' }, 'Twitter')
    assert_equal modified_item['likes'], 20
  end

  def test_social_facebook_object_should_fetch_feeds_from_dynamo
    handle = get_twitter_handle
    @default_stream = handle.default_stream
    feed_id = (Time.now.utc.to_f * 100_000).to_i
    stream_id = "#{@account.id}_#{@default_stream.id}"
    Aws::DynamoDB::Client.any_instance.stubs(:get_item).returns(sample_dynamo_get_item_params)
    Aws::DynamoDB::Client.any_instance.stubs(:batch_get_item).returns(sample_interactions_batch_get(feed_id).first)
    fb_dynamo = Social::Dynamo::Facebook.new
    response = fb_dynamo.fetch_feeds(feed_id, stream_id)
    assert response
  ensure
    Aws::DynamoDB::Client.any_instance.unstub(:get_item)
    Aws::DynamoDB::Client.any_instance.unstub(:batch_get_item)
  end
end
