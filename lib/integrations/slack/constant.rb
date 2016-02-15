#Belongs to Old Slack, remove file when slackV1 is obselete.
module Integrations::Slack::Constant

	SLACK_REST_API = {
		:test         => "https://slack.com/api/auth.test?",
		:postMessage  => "https://slack.com/api/chat.postMessage?",
		:history      => "https://slack.com/api/im.history?",
		:channel_list => "https://slack.com/api/channels.list?",
		:user_list    => "https://slack.com/api/users.list?"
	}

	USERNAME = "Freshdesk"

	ICON_URL = "http://login.freshdesk.com/images/admin-logo.png"

	SLACK_BOT = "USLACKBOT"

	STATUS_UPDATE = "status_update"

	TICKET_CREATE = "ticket_create"
	
	NOTE_CREATE   = "note_create"

	FD_ACTIONS = [NOTE_CREATE,TICKET_CREATE,STATUS_UPDATE]

end
