class Freshfone::CallCostCalculator
	attr_accessor :args, :current_account, :first_leg_call, :total_charge, :current_call
	DEFAULT_CALL_COST = -1.0

	def initialize(args, current_account)
		self.args = args
		self.current_account = current_account
		self.total_charge = DEFAULT_CALL_COST
	end
	
	
	def perform
		begin
			calculate_cost
		rescue => exp
			Freshfone::PulseRate.send_failure_notification(Account.current, args[:call_sid],
				 																																args[:dial_call_sid])
			puts "Freshfone ERROR: TOTAL Call Cost :#{total_charge}:  #{exp} : \n #{exp.backtrace}"
		ensure
			puts "Freshfone INFO ::Credit Updated >>> USD:  #{total_charge} :: isrecord :#{args[:record].present?}"
			update_call_cost
		end
	end
	
	def calculate_cost
		self.first_leg_call = get_twilio_call
		calculate_second_leg_cost

		puts "CALL COST :: #{total_charge}"
		raise "Call Cost is Negative!!!" if total_charge < 0
	end
	
	private
		def get_first_leg_cost
			#twilio returned call charge is always negative hence .abs
			puts "Call cost for the first leg of #{args[:call_sid]} : #{first_leg_call.price}"
			self.total_charge = first_leg_call.price.to_f.abs 
		end
	
		def calculate_second_leg_cost
			set_current_call
			return get_first_leg_cost if !transferred? && (dial_call_sid.blank? || current_call.blank? || no_call_duration?)

			dial_call_cost
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
			# calculate the charge for duration.(cost from freshfone_charges.yml)
			pulse_rate = Freshfone::PulseRate.new(current_call, args[:call_forwarded])
			dial_call_charge = pulse_rate.pulse_charge
			self.total_charge = dial_call_charge.to_f * no_of_pulse(first_leg_call_duration)
		end
		
		def update_call_cost
			# update call cost /special ignore update case if it is for record message,
			# we don't store call data for record twiml but twilio charge needs to be deducted
			current_call.root.update_attribute(:call_cost, total_charge) if can_update_call_record?(args)
			current_account.freshfone_credit.update_credit(total_charge) if total_charge > 0
			#Otherbilling for preview & Message_records
			current_account.freshfone_credit.other_charges(total_charge, 
			args[:billing_type], args[:number_id]) unless args[:billing_type].blank? 
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

		def current_call_duration
			current_call.call_duration unless current_call.blank?
		end
		
		def no_call_duration?
			(current_call_duration.blank? or current_call_duration == 0 )
		end
		
		def first_leg_call_duration
			#first leg duration is the call full duration.
			first_leg_call.duration.to_i
		end
		
		def can_update_call_record?(args)
			args[:billing_type].blank? and current_call.present?
		end
end