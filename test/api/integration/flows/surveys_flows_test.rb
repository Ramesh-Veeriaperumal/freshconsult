require_relative '../../test_helper'

class SurveysFlowsTest < ActionDispatch::IntegrationTest
  include Redis::RedisKeys
  include Redis::OthersRedis
  @@before_all = false

  def setup
    super
    before_all
  end

  def before_all
    return if @@before_all
    @@before_all = true
    @account.launch(:falcon)
  end

  def test_index_without_timestamp
    get '/api/_/surveys', nil, @headers
    assert_response 200
  end

  def test_index_with_same_etag
    redis_timestamp = 1.day.ago.to_i
    $redis_others.hset(version_redis_key, 'SURVEY_LIST', redis_timestamp)
    @write_headers = @headers.merge('If-None-Match' => EtagGenerator.generate_etag(redis_timestamp))
    get '/api/_/surveys', nil, @write_headers
    assert_response 304
  end

  def test_index_with_different_etag
    $redis_others.hset(version_redis_key, 'SURVEY_LIST', Time.zone.now.to_i)
    @write_headers = @headers.merge('If-None-Match' => EtagGenerator.generate_etag(1.hour.ago.to_i))
    get '/api/_/surveys', nil, @write_headers
    assert_response 200
  end

  def version_redis_key
    DATA_VERSIONING_SET % { account_id: @account.id }
  end
end
