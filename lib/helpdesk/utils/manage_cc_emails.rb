# encoding: utf-8

module Helpdesk::Utils::ManageCcEmails

	include ParserUtil

	def filter_cc_emails account, emails_array, requester_email=""
		emails_array = fetch_valid_emails(emails_array)
		configured_emails = []
		account.all_email_configs.each { |ec| configured_emails << ec.reply_email }
		cc_email_val = emails_array.delete_if { |cc_email| (configured_emails.include? parse_email_text(cc_email)[:email]) || (parse_email_text(cc_email)[:email] == requester_email) }
		cc_email_val.uniq
	end

end