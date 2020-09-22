# class Freshfone::Call < ActiveRecord::Base
# 	include RepresentationHelper

# 	DATETIME_FIELDS = ["created_at", "updated_at"]
# 	acts_as_api

# 	# Need to add further fields.
# 	api_accessible :central_publish do |t|
# 		t.add :id
# 		t.add :call_status_hash, as: :call_status
# 		DATETIME_FIELDS.each do |key|
# 			t.add proc { |x| x.utc_format(x.safe_send(key)) }, as: key
# 		end
# 	end
	
# 	def call_status_hash
# 		{
# 			"id": call_status,
# 			"name": Freshfone::Call::CALL_STATUS_REVERSE_HASH[call_status]
# 		}
# 	end
# end