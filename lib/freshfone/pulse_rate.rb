class Freshfone::PulseRate

	FRESHFONE_CHARGES = YAML::load_file(File.join(Rails.root, 'config/freshfone',
																									'freshfone_charges.yml'))
	attr_accessor :call, :number, :country, :forwarded, :credit
	
	delegate :incoming?, :caller_country, :customer_number, :freshfone_number, :outgoing?,
						:to => :call, :allow_nil => true
	delegate :number_type, :to => :freshfone_number, :allow_nil => true
	delegate :country, :to => :freshfone_number, :prefix => true, :allow_nil => true
	
	COUNTRY_CALL_TYPES = {
		'US' => :usca_tollfree,
		'CA' => :usca_tollfree,
		'GB' => :uk_tollfree,
		'default' => :standard
	}
	
	def initialize(call, forwarded)
		self.call = call
		self.forwarded = forwarded
		self.credit = -1.0
	end

	def pulse_charge
		return outgoing_cost if outgoing?
		forwarded ? forwarded_cost : incoming_cost
	end
	
	def self.send_failure_notification(account, call_sid, dial_call_sid)
		puts "FRESHFONE ERROR :: FAILURE ON CREDIT CALCULATION for account #{account} #{call_sid}::#{dial_call_sid} "
		# FreshfoneNotifier.billing_failure(account, call_sid, dial_call_sid)//TODO Enable before deploying for mail notification
	end

	private

		def outgoing_cost
			self.country = caller_country
			self.number = customer_number

			puts "INSIDE OUTGOING...#{country} : #{number}"
			calculate(:outgoing)
		end

		def incoming_cost
			self.country = call.freshfone_number.country
			self.number = call.freshfone_number.number

			puts "INSIDE INCOMING....#{country} : #{number}.."
			return FRESHFONE_CHARGES['INCOMING'][forwarded_call_type].to_f #incoming direct fetch 
		end

		def forwarded_cost
			self.number = call.direct_dial_number || call.agent.available_number
			self.country =  GlobalPhone.parse(number).territory.name unless GlobalPhone.parse(number).blank?

			puts "INSIDE FWD....#{country} : #{number}.."
			calculate(forwarded_call_type)
		end

		# MaxLength of the existing numbers  
		# number array is in the order of most digits to less.
		# Matching will check in the same orderly so that we match most digits first
		# Always maintain most digits number first in the array(in freshfone_charges.yml)
		def calculate(call_type)
			return credit if country_invalid?

			puts "Freshfone INFO CallType:: #{call_type}"
			get_matching_country_cost(call_type)
			Rails.logger.info "Freshfone CallCost:::#{credit}"
			return credit
		end


		def forwarded_call_type
			type = COUNTRY_CALL_TYPES[freshfone_number_country] if toll_free_number?
			type || COUNTRY_CALL_TYPES['default']
		end

		def forwarded?
			forwarded
		end
	
		def country_invalid?
			(country.blank? || FRESHFONE_CHARGES[country].blank?)
		end
	
		def toll_free_number?
			number_type == Freshfone::Number::TYPE_HASH[:toll_free]
		end

		def strip_plus_sign(number)
			#removing additional '+' if exists to do matching	
			number.start_with?('+') ? number[1..-1] : number
		end

		def get_matching_country_cost(call_type)
			formatted_number = strip_plus_sign(number)
			max_length = FRESHFONE_CHARGES[country][:max_digits]
			max_length.times do |index|
				shortened_number = formatted_number[0..(max_length - index - 1)]
				FRESHFONE_CHARGES[country][:numbers].each_pair do |number_array, cost_type|
					number_array = number_array.split(',')
					if number_array.include? shortened_number
						return self.credit = cost_type[call_type].to_f
					end
				end
			end
		end
end