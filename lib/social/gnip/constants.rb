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
	
	# time in sec
	TIME = { 
		:max_time_in_sqs => 240,
		:replay_stream_timeout => 60,
		:reconnect_timeout => 30,
		:replay_stream_wait_time => 1800
	}

	MSG_COUNT_FOR_UPDATING_REDIS = 15

	GNIP_DISCONNECT_LIST = "gnip_disconnect"

end
