require_relative '../../test_helper'

class TicketFieldsFlowsTest < ActionDispatch::IntegrationTest
  include Redis::RedisKeys
  include Redis::OthersRedis
  CURRENT_VERSION = 'private-v4'.freeze
  def sample_user
    @account.all_agents.first
  end

  @@before_all = false

  def setup
    CustomRequestStore.store[:private_api_request] ||= true
    super
    before_all
  end

  def before_all
    return if @@before_all
    @@before_all = true
  end

  def test_index_without_timestamp
    get '/api/_/ticket_fields', nil, @headers
    assert_response 200
  end

  #def test_index_with_same_etag
  #  redis_timestamp = 1.day.ago.to_i
  #  $redis_others.hset(version_redis_key, 'TICKET_FIELD_LIST', redis_timestamp)
  #  @write_headers = @headers.merge('If-None-Match' => EtagGenerator.generate_etag(redis_timestamp, CURRENT_VERSION))
  #  get '/api/_/ticket_fields', nil, @write_headers
  #  assert_response 304
  #end

  def test_index_with_different_etag
    $redis_others.hset(version_redis_key, 'TICKET_FIELD_LIST', Time.zone.now.to_i)
    @write_headers = @headers.merge('If-None-Match' => EtagGenerator.generate_etag(1.hour.ago.to_i, CURRENT_VERSION))
    get '/api/_/ticket_fields', nil, @write_headers
    assert_response 200
  end

  def test_index_without_updating_version_timestamp
    redis_timestamp = Time.zone.now.to_i
    $redis_others.hset(version_redis_key, 'TICKET_FIELD_LIST', redis_timestamp)
    @write_headers = @headers.merge('If-None-Match' => EtagGenerator.generate_etag(1.hour.ago.to_i, CURRENT_VERSION))
    get '/api/_/ticket_fields', nil, @write_headers
    assert_response 200
    new_redis_value = get_others_redis_hash_value(version_redis_key, 'TICKET_FIELD_LIST')
    assert_not_equal new_redis_value, redis_timestamp
  end

  # Test etag change for skill update. as skill have been added as part of ticket field manually.
  def test_index_etag_with_skill_update
    redis_timestamp = 1.day.ago.to_i
    $redis_others.hset(version_redis_key, 'TICKET_FIELD_LIST', redis_timestamp)
    skills = @account.skills.create(:name => Faker::Lorem.words(3).join(' '), :match_type => "all")
    @write_headers = @headers.merge('If-None-Match' => EtagGenerator.generate_etag(redis_timestamp, CURRENT_VERSION))
    get '/api/_/ticket_fields', nil, @write_headers
    assert_response 200
    new_redis_value = get_others_redis_hash_value(version_redis_key, 'TICKET_FIELD_LIST')
    assert_not_equal new_redis_value, redis_timestamp
  end

  def version_redis_key
    DATA_VERSIONING_SET % { account_id: @account.id }
  end
end
