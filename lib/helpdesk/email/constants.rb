module Helpdesk::Email::Constants

	# DBTYPE = "primary"

	DUMMY_RANDOM_S3_PREFIX = "XXXX"
	NO_OF_RANDOM_S3_PREFIX = 32


	EMAIL_PROCESSING_STATE = { :in_process => 0, :finished => 1, :archived => 2, :failed => 3 }
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
								:failed_article => "Article creation failed" 
							} # add according to need
	PROCESSED_EMAIL_TYPE = { :ticket => "ticket", :note => "note", :article => "article", :invalid => "invalid" }

	FAILED_EMAIL_PATH = "failed_email_path"

	MESSAGE_TYPE_BY_NAME = { :spam => 1, :ham => 0 }

	MAX_EMAIL_SIZE = 30.megabyte

end
