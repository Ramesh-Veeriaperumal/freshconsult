class Freshfone::CallerId < ActiveRecord::Base

  self.table_name = :freshfone_caller_ids
  self.primary_key = :id

  belongs_to_account
  has_many :freshfone_numbers, :class_name => 'Freshfone::Number',:foreign_key => :caller_id

  before_destroy :delete_twilio_caller_id

  ERROR_MESSAGES = { 13225 => I18n.t('freshfone.admin.numbers.caller_id.twilio_errors.not_allowed'),
                     21212 => I18n.t('freshfone.admin.numbers.caller_id.twilio_errors.invalid_number'),
                     21215 => I18n.t('freshfone.admin.numbers.caller_id.twilio_errors.not_allowed'),
                     21216 => I18n.t('freshfone.admin.numbers.caller_id.twilio_errors.not_allowed'),
                     21217 => I18n.t('freshfone.admin.numbers.caller_id.twilio_errors.invalid_number'),
                     21220 => I18n.t('freshfone.admin.numbers.caller_id.twilio_errors.not_allowed'),
                     21401 => I18n.t('freshfone.admin.numbers.caller_id.twilio_errors.not_allowed'),
                     21421 => I18n.t('freshfone.admin.numbers.caller_id.twilio_errors.invalid_number'),
                     21450 => I18n.t('freshfone.admin.numbers.caller_id.twilio_errors.already_verified'),
                     :Default => I18n.t('freshfone.admin.numbers.caller_id.error_message')
                    }

  private

    def twilio_account
      account.freshfone_account.freshfone_subaccount
    end

    def delete_twilio_caller_id
      begin
        caller = twilio_account.outgoing_caller_ids.get(self.number_sid)
        caller.delete
      rescue Twilio::REST::RequestError => e
        Rails.logger.error "Error deleting number for Account : #{account.id} \n#{e.message}\n#{e.backtrace.join("\n\t")}"
      end 
    end

end
