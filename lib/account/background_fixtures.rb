module Account::BackgroundFixtures

	extend ActiveSupport::Concern

	include Redis::RedisKeys
	include Redis::OthersRedis

	STATUS_MAP = {:enqueued => 0, :started => 1,
		     :awaiting_retry => -1, :failed => -2 }


  def background_fixtures_status
  	status = get_others_redis_key(status_key)
  	status.present? ?  status.to_i : nil
  end

  STATUS_MAP.keys.each do |status|
  	define_method "set_background_fixtures_#{status}" do
  		set_others_redis_key(status_key, STATUS_MAP[status])
  		Rails.logger.info "Background Fixtures: #{self.id} Current status - #{status} "
  	end

  	define_method "background_fixtures_#{status}?" do
  		background_fixtures_status == STATUS_MAP[status]
  	end
  end

  def background_fixtures_completed
    remove_others_redis_key(status_key)
    Rails.logger.info "Background Fixtures: #{self.id} Current status - completed"
  end

  def background_fixtures_running?
  	background_fixtures_started?
  end

  private

    def status_key
      key = BACKGROUND_FIXTURES_STATUS % {:account_id => self.id}
    end


end