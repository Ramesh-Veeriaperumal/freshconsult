class Freshfone::OtherCharge < ActiveRecord::Base
  self.primary_key = :id
	self.table_name =  :freshfone_other_charges
	belongs_to_account

	ACTION_TYPE = [
		[:number_purchase, 'Number Purchase', 1],
		[:number_renew, 'Number Renew', 2],
		[:ivr_preview, 'IVR Preview', 3],
		[:message_record, 'Message record', 4]
	]
	ACTION_TYPE_HASH = Hash[*ACTION_TYPE.map { |i| [i[0], i[2]] }.flatten]
	ACTION_TYPE_STR_HASH = Hash[*ACTION_TYPE.map { |i| [i[1].to_s, i[2]] }.flatten]
	ACTION_TYPE_STR_REVERSE_HASH = Hash[*ACTION_TYPE.map { |i| [i[2], i[1]] }.flatten]
end
