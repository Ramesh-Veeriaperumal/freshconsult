class Freshfone::PulseRate

	FRESHFONE_CHARGES = YAML::load_file(File.join(Rails.root, 'config/freshfone',
																									'freshfone_charges.yml'))
	attr_accessor :call, :number, :country, :forwarded, :credit
	
	delegate :incoming?, :caller_country, :caller_number, :freshfone_number, :outgoing?,
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

	def one_legged_call_cost
		self.country = call.freshfone_number.country
		self.number = call.freshfone_number.number
		return FRESHFONE_CHARGES['VOICEMAIL'][forwarded_call_type].to_f		
	end

	def missed_call_cost
		FRESHFONE_CHARGES['MISSED_OR_BUSY'].to_f
	end

	private

		def outgoing_cost
			self.country = caller_country
			self.number = caller_number

			calculate(:outgoing)
		end

		def incoming_cost
			self.country = call.freshfone_number.country
			self.number = call.freshfone_number.number

			return FRESHFONE_CHARGES['INCOMING'][forwarded_call_type].to_f #incoming direct fetch 
		end

		def forwarded_cost
			self.number = call.direct_dial_number || call.agent.available_number
			self.country =  GlobalPhone.parse(number).territory.name unless GlobalPhone.parse(number).blank?

			calculate(forwarded_call_type)
		end

		# MaxLength of the existing numbers  
		# number array is in the order of most digits to less.
		# Matching will check in the same orderly so that we match most digits first
		# Always maintain most digits number first in the array(in freshfone_charges.yml)
		def calculate(call_type)
			country_from_global if country_invalid?

			get_matching_country_cost(call_type) unless country_invalid? #if global country code too is invalid
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
	
		def country_from_global
			self.country =  GlobalPhone.parse(number).territory.name unless GlobalPhone.parse(self.number).blank?
		end

		def toll_free_number?
			number_type == Freshfone::Number::TYPE_HASH[:toll_free]
		end

		def ignore_format(number)
			number.gsub(/\D/, '')#returns just the number. hyphens, blank space, leading plus everthing is removed.
		end

		def get_matching_country_cost(call_type)
			formatted_number = ignore_format(number)
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