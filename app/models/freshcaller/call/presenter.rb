# class Freshcaller::Call < ActiveRecord::Base
# 	include RepresentationHelper

# 	DATETIME_FIELDS = ["created_at", "updated_at"]
# 	acts_as_api

# 	# Need to add further fields.
# 	api_accessible :central_publish do |t|
# 		t.add :id
# 		t.add :fc_call_id
# 		t.add :recording_status_hash, as: :recording_status
# 		DATETIME_FIELDS.each do |key|
# 			t.add proc { |x| x.utc_format(x.safe_send(key)) }, as: key
# 		end
# 	end
	
# 	def recording_status_hash
# 		{
# 			"id": recording_status,
# 			"name":	Freshcaller::Call::RECORDING_STATUS_NAMES_BY_KEY[recording_status]
# 		}
# 	end
# end