class Freshfone::NumberObserver < ActiveRecord::Observer
	observe Freshfone::Number

	def before_validation(freshfone_number)
    unless freshfone_number.new_record?
      build_message_hash(freshfone_number) if freshfone_number.message_changed?
    end
    freshfone_number
	end

	def before_save(freshfone_number)
		handle_attachments(freshfone_number)
	end

	def before_create(freshfone_number)
		account = freshfone_number.account
		create_subaccount(freshfone_number, account) if new_freshfone_account?(account)
		build_ivr_for_number(freshfone_number, account)
		add_number_to_twilio(freshfone_number, account) unless freshfone_number.skip_in_twilio
		set_number_config(freshfone_number, account)
	end

	def after_create(freshfone_number)
		account = freshfone_number.account
		update_freshfone_credit(freshfone_number, account) if active_freshfone_account?(account)
		address_certification_request(freshfone_number, account) if active_freshfone_account?(account)
	end

	def before_update(freshfone_number)
		account = freshfone_number.account
		delete_from_twilio(freshfone_number, account) if freshfone_number.deleted_changed?
	end

	private
		def delete_from_twilio(freshfone_number, account)
			twilio_account = account.freshfone_account.twilio_subaccount
			twilio_account.incoming_phone_numbers.get(freshfone_number.number_sid).delete if freshfone_number.deleted
		end

		def handle_attachments(freshfone_number)
			freshfone_number.attachments.each { |a| a.save if a.new_record? }
			map_attachments(freshfone_number)
		end

		def map_attachments(freshfone_number)
			(freshfone_number.attachments_hash || {}).each_pair do |type, attachment|
				freshfone_number[type].attachment_id = attachment.id
			end
		end

		def create_subaccount(freshfone_number, account)
			account.create_freshfone_account
		end

		def build_ivr_for_number(freshfone_number, account)
			freshfone_number.build_ivr({ :account => account, :active => false })
		end

		def add_number_to_twilio(freshfone_number, account)
			number = account.freshfone_subaccount.incoming_phone_numbers.create(
														:phone_number => freshfone_number.number, 
														:voice_application_sid => account.freshfone_account.app_id )
			freshfone_number.number_sid = number.sid unless number.blank?
		end

		def set_number_config(freshfone_number, account)
			number_type = Freshfone::Number::TYPE_STR_REVERSE_HASH[freshfone_number.number_type]
			freshfone_number.rate = Freshfone::Cost::NUMBERS[freshfone_number.country][number_type]
			freshfone_number.business_calendar = account.business_calendar.default.first
			freshfone_number.next_renewal_at = 1.month.from_now - 1.day
			construct_default_message(freshfone_number)
		end

		def update_freshfone_credit(freshfone_number, account)
			account.freshfone_credit.deduce(freshfone_number.rate)
			account.freshfone_other_charges.create(
				:action_type => Freshfone::OtherCharge::ACTION_TYPE_HASH[:number_purchase],
				:debit_payment => freshfone_number.rate,
				:freshfone_number_id => freshfone_number.id)
		end
		
		def address_certification_request(freshfone_number, account)
			return unless freshfone_number.address_required
			FreshfoneNotifier.send_later(:deliver_address_certification, account, freshfone_number)
		end
		
		def new_freshfone_account?(account)
			account.freshfone_account.blank?
		end
		
		def active_freshfone_account?(account)
			#Currently checks only active SUBSCRIPTION. should check for freshfone trial as well when implemented.
			account.subscription.active?
		end
		
		def build_message_hash(freshfone_number)
			Freshfone::Number::MESSAGE_FIELDS.each do |msg_type|
				message = freshfone_number[msg_type] || {}
				freshfone_number[msg_type] = Freshfone::Number::Message.new({
					:attachment_id => message["attachment_id"].blank? ? nil : message["attachment_id"].to_i,
					:message => CGI::escapeHTML(message["message"]),
					:message_type => message["message_type"].to_i,
					:recording_url => message["recording_url"],
					:type => msg_type
				})
			end
		end

		def construct_default_message(freshfone_number)
			Freshfone::Number::MESSAGE_FIELDS.each do |msg_type|
				freshfone_number[msg_type] = Freshfone::Number::Message.new({
					:attachment_id => nil,
					:message => Freshfone::Number::Message::DEFAULT_MESSAGE[msg_type],
					:message_type => Freshfone::Number::Message::MESSAGE_TYPES[:transcript],
					:recording_url => "",
					:type => msg_type
				})
			end
		end

end