module MemcacheReadWriteMethods

	def newrelic_begin_rescue(&block)
		begin
			block.call
		rescue Dalli::UnmarshalError => e
			x = ["undefined class/module CompanyField","undefined class/module ContactFieldChoice",
					"undefined class/module CustomSurvey::SurveyQuestion"]
			if x.any? {|word| e.message.include?(word)}
				 Rails.logger.debug "#{Account.current}  #{e.message}"
			end
			NewRelic::Agent.notice_error(e)
			return
		rescue Exception => e
			NewRelic::Agent.notice_error(e)
			return
		end
	end

	def get_from_cache(key, raw=false)
		newrelic_begin_rescue { memcache_client.get(key, raw) }
	end

	def cache(key,value,expiry=0, raw=false)
		newrelic_begin_rescue { memcache_client.set(key, value, expiry, raw) }
	end

	def delete_from_cache(key)
		newrelic_begin_rescue { memcache_client.delete(key) }
	end

	def set_null(value)
		value.nil? ? NullObject.instance : value
	end

	def unset_null(value)
		value.is_a?(NullObject) ? nil : value
	end

	def fetch(key, expiry=0, after_cache_msg = nil, &block)
		key = ActiveSupport::Cache.expand_cache_key(key) if key.is_a?(Array)
		cache_data = get_from_cache(key)
		if cache_data.nil?
			Rails.logger.debug "Cache hit missed :::::: #{key}"
			cache(key, (cache_data = set_null(block.call)), expiry)
		else
			Rails.logger.debug "::::: #{after_cache_msg} :::::: #{key}" if after_cache_msg
		end
		unset_null(cache_data)
	end
end