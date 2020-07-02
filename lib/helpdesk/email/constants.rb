module Helpdesk::Email::Constants

	# DBTYPE = "primary"

	DUMMY_RANDOM_S3_PREFIX = "XXXX"
	NO_OF_RANDOM_S3_PREFIX = 32


	EMAIL_PROCESSING_STATE = { :in_process => 0, :finished => 1, :archived => 2, :processing_failed => 3, :archive_failed =>4, :permanent_failed =>5 }
	PROCESSING_TIMEOUT = Helpdesk::EMAIL[:processing_timeout] # should be same as visibility timeout , move to place where visibilty timeout is set

	DBTYPE = { :primary => :primary , :archive => :archive, :failed => :failed }
	DB_STORAGE = { :s3 => :s3 }

	QUEUETYPE  = { :sqs => :sqs }
	EMAIL_QUEUE = { 
		'trial'  	=> SQS[:trial_customer_email_queue], 
		'active' 	=> SQS[:active_customer_email_queue], 
		'free'   	=> SQS[:free_customer_email_queue],
		'default' => SQS[:default_email_queue],
		'failed' 	=> SQS[:email_dead_letter_queue]
	}

	PROCESSED_EMAIL_STATUS = { 	:success => "success",
								:failed => "failed", 
								:shard_mapping_failed => "Shard mapping failed",
								:invalid_from_email => "Invalid from address",
								:restricted_domain_access => "Restricted domain access",
								:self_email => "Email to self",
								:duplicate => "Duplicate email",
								:user_blocked => "User blocked",
								:blank_user => "No User",
								:invalid_account => "Invalid account",
								:inactive_account => "Inactive account",
								:failed_article => "Article creation failed",
								:max_email_limit => "Reached max allowed email limit in Ticket/Note",
								:noop_collab_email_reply => "No Operation: Collab Email Reply ",
                :wildcard_email => 'Wildcard Email '
							} # add according to need
	PROCESSED_EMAIL_TYPE = { :ticket => "ticket", :note => "note", :article => "article", :invalid => "invalid" }

	FAILED_EMAIL_PATH = "failed_email_path"
	
	FAILURE_CATEGORY = ["dropped", "dropped_unsubscribed", "bounce_temporary", "bounce_permanent"]

	MESSAGE_TYPE_BY_NAME = { :spam => 1, :ham => 0 }

	MAX_EMAIL_SIZE = 30.megabyte

	TRUNCATE_CONTENT = [:text, :html]
	TRUNCATE_SIZE = 500.kilobyte
	MAXIMUM_CONTENT_LIMIT = 300.kilobytes
	LARGE_TEXT_TIMEOUT = 60

	RETRY_FAILED_MESSAGE_PATH = "retry_failed_messages"
	PERMANENT_FAILED_MESSAGE_PATH = "dead_failed_messages"
	CUSTOM_BOT_RULES = ['CUSTOM_BOT_ATTACK', 'CUSTOM_RUSSIAN_SPAM'].freeze
	EMAIL_RATE_LIMIT_ADMIN_ALERT_EXPIRY = 24 * 3600
	EMAIL_RATE_LIMIT_BANNER_THRESHOLD = 8
end
