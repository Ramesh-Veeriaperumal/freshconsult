class Freshfone::CallCostCalculator
	include Redis::RedisKeys
	include Redis::IntegrationsRedis
	attr_accessor :args, :current_account, :first_leg_call, :total_charge, :current_call
	delegate :outgoing?, :to => :current_call, :allow_nil => true
	DEFAULT_CALL_COST = -1.0

	def initialize(args, current_account)
		self.args = args
		self.current_account = current_account
		self.total_charge = DEFAULT_CALL_COST
	end
	
	def perform
		begin
			set_current_call
			calculate_cost
		rescue => exp
			puts "Freshfone ERROR: TOTAL Call Cost :#{total_charge}:  #{exp} : \n #{exp.backtrace}"
			FreshfoneNotifier.billing_failure(Account.current, args[:call_sid], exp)
		ensure
			puts "Freshfone INFO ::Credit Updated >>> USD:  #{total_charge} :: isrecord :#{args[:record].present?}"
			update_call_cost
			update_calls_beyond_threshold_count
		end
	end
	
	def calculate_cost
		return missed_call_cost if missed_or_busy?
		self.first_leg_call = get_twilio_call
		get_first_leg_cost
		dial_call_cost unless one_leg_calls?

		raise "Call Cost is Negative!!!" if total_charge < 0
	end
	
	private

		def one_leg_calls?
			!transferred? && (dial_call_sid.blank? || no_call_duration?)
		end

		def get_first_leg_cost
			puts "Call cost for the first leg of #{args[:call_sid]} : #{first_leg_call.price}"
			self.total_charge = current_call.present? ? pulse_rate.one_legged_call_cost	: first_leg_call.price.to_f.abs
		end
	
		def missed_call_cost
			self.total_charge = pulse_rate.missed_call_cost
		end

		def transferred?
			args[:transfer]
		end
		
		def no_of_pulse(duration)
			duration = duration.to_f/60
			(duration > duration.round) ? (duration.round + 1) : duration.round
		end
		
		#have separate dial call cost for transfer-to-voicemail scenario
		def dial_call_cost
			pulse_cost = pulse_rate.pulse_charge
			self.total_charge = pulse_cost.to_f * no_of_pulse(first_leg_call_duration)
		end
		
		def update_call_cost
			# update call cost /special ignore update case if it is for record message,
			# we don't store call data for record twiml but twilio charge needs to be deducted
			if total_charge > 0
				current_call.root.update_attribute(:call_cost, total_charge) if can_update_call_record?(args)
				current_account.freshfone_credit.update_credit(total_charge)
				#Otherbilling for preview & Message_records
				current_account.freshfone_other_charges.create(
					:debit_payment => total_charge,
					:action_type => args[:billing_type],
					:freshfone_number_id => args[:number_id]) unless args[:billing_type].blank? 
			else
				Rails.logger.debug "Total charge is zero for call :: #{args[:call_sid]} :: transferred? #{transferred?} 
				:: dial_call_sid #{dial_call_sid} :: current_call #{current_call.blank?} :: no_call_duration #{no_call_duration?} :: total_charge #{total_charge}"
			end
		end
		
		def update_calls_beyond_threshold_count
			return if args[:below_safe_threshold].blank?
			key = FRESHFONE_CALLS_BEYOND_THRESHOLD % { :account_id => current_account.id }
			set_key(key, calculate_calls_count)
		end

		def beyond_threshold_calls_count
			@beyond_threshold_calls_count ||= begin
				key = FRESHFONE_CALLS_BEYOND_THRESHOLD % { :account_id => current_account.id }
				get_key(key).to_i
			end
		end
		
		def calculate_calls_count
			# First four bits for outgoing(0b0000xxxx), next four bits for incoming(0bxxxx0000)
			incoming = beyond_threshold_calls_count >> 4
			outgoing = beyond_threshold_calls_count & 15
			if outgoing?
				outgoing = (outgoing > 0) ? (outgoing - 1) : 0
			else
				incoming = (incoming > 0) ? (incoming - 1) : 0
			end
			(incoming << 4) + outgoing
		end

		def call_sid
			args[:call_sid]
		end
		
		def dial_call_sid
			args[:dial_call_sid]
		end
		
		def get_twilio_call
			current_account.freshfone_subaccount.calls.get call_sid unless call_sid.blank?
		end
		
		def set_current_call
			self.current_call = (args[:call]) ? 
										current_account.freshfone_calls.find_by_id(args[:call]) :
										current_account.find_by_call_sid(call_sid)
		end


		def pulse_rate
			@pulse_rate ||= Freshfone::PulseRate.new(current_call,  args[:call_forwarded]) if current_call.present?
		end

		def current_call_duration
			current_call.call_duration unless current_call.blank?
		end
		
		def no_call_duration?
			(current_call.blank? || current_call_duration.blank? or current_call_duration == 0 )
		end
		
		def first_leg_call_duration
			#first leg duration is the call full duration.
			first_leg_call.duration.to_i
		end
		
		def can_update_call_record?(args)
			args[:billing_type].blank? and current_call.present?
		end

		def missed_or_busy?
			return false if current_call.blank? #Recording or IVR Preview Cost
			[ Freshfone::Call::CALL_STATUS_HASH[:busy],
				 Freshfone::Call::CALL_STATUS_HASH[:'no-answer']].include?(current_call.call_status)
		end

end