module RestrictControllerAction
	include Redis::OthersRedis
	include Redis::RedisKeys

	INIT_VALUE = 1
	PERFORM_LIMIT = 5
	PERFORM_EXPIRY = 3600 #1 hour
	
	def self.included(controller)
		controller.extend(ClassMethods)
		controller.before_filter(:restrict)
	end

	module ClassMethods
		def restrict_perform(*actions)
			write_inheritable_array(:restrict_actions, actions)
		end
	end


	protected
		def restrict_perform?
			(self.class.read_inheritable_attribute(:restrict_actions) || []).include?(action_name.to_sym)
		end

	  def key
			#to be defined in the included class
	  end

	  #The following two methods restrict the action to be performed to 5 times in an hour.
	  #The methods can be overridden in the included class.
		def perform_limit
			PERFORM_LIMIT 
	  end

	  def perform_expiry
			PERFORM_EXPIRY
	  end

	  #Message to be displayed if perform limit exceeded. Can be overridden in the included class.
	  def perform_limit_exceeded_message
			t('flash.general.limit_exceeded')
	  end

		def performed_count
			get_others_redis_key(key).to_i
		end

		def never_performed?
			performed_count == 0
		end

		def perform_limit_exceeded?
			performed_count >= perform_limit
		end

		def redirect_url
			{ :action => "show" }
		end

	private
		def restrict
			return unless restrict_perform?
			return if key.blank?
			
			case 
			when never_performed?
				set_others_redis_key(key, INIT_VALUE, perform_expiry)
			when perform_limit_exceeded?
				flash[:notice] = perform_limit_exceeded_message
				redirect_to redirect_url
			else
				if request.post?
					expiry = get_others_redis_expiry(key)
					set_others_redis_key(key, performed_count+1, expiry)
				end
			end
		end
end