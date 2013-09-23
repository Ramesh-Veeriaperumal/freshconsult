module Social::Gnip::Constants

	DELIMITER = {
		:tags => ":",
		:tag_elements => "_",
		:production_stream => "\r\n",
		:replay_stream => "\r\n\r\n"
	}

	RULE_ACTION = {
		:update => {
			:success => true, 
			:failure => false
		},
		:add => "add",
		:delete => "delete"
	}

	STREAM = {
		:replay => "replay",
		:production => "production"
	}
	
	TIME_IN_SEC = {
		:max_time_in_sqs => 300,
		:gnip_timeout => 60,
		:replay_stream_wait_time => 30
	}

	MSG_COUNT_FOR_UPDATING_REDIS = 15

	GNIP_DISCONNECT_LIST = "gnip_disconnect"

end
