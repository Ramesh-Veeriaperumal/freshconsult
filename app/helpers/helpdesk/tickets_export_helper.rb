module Helpdesk::TicketsExportHelper
	include Redis::RedisKeys

	EXPORT_DATE_FORMAT = {:format => :short_day_separated, :include_year => true, :translate => false}

	def export_fields_redis
		@export_fields_from_redis ||= tickets_redis_list(export_redis_key)
	end

	def export_redis_key
    	EXPORT_TICKET_FIELDS % {:account_id => current_account.id, :user_id => current_user.id, :session_id => request.session_options[:id]}
  	end

end