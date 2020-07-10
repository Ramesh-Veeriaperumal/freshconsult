class Freshfone::PulseRate
	include Freshfone::NumberValidator

	# PRE-RAILS: Psych parse error when loading YAML::load_file(File.join(Rails.root, 'config/freshfone', 'freshfone_charges.yml')) 
	# as key is too lengthly, so we moved the yml to constant file for now.
	FRESHFONE_CHARGES = Freshfone::YmlConstants::CHARGES
	attr_accessor :call, :number, :country, :forwarded, :credit
	
	delegate :incoming?, :caller_country, :caller_number, :freshfone_number, :outgoing?,
						:to => :call, :allow_nil => true
	delegate :number_type, :to => :freshfone_number, :allow_nil => true
	delegate :country, :to => :freshfone_number, :prefix => true, :allow_nil => true
	
	COUNTRY_CALL_TYPES = {
		'US' => :us_tollfree,
		'CA' => :ca_tollfree,
		'GB' => :uk_tollfree,
		'AU' => :au_tollfree,
		'default' => :standard
	}
	
	def initialize(call=nil, forwarded=nil)
		self.call = call
		self.forwarded = forwarded
		self.credit = -1.0
	end

	def pulse_charge
		return forwarded_cost if call_forwarded?
		return outgoing_cost if outgoing?
		incoming_cost
	end

	def voicemail_cost
		self.country = call.freshfone_number.country
		self.number = call.freshfone_number.number
		return FRESHFONE_CHARGES['VOICEMAIL'][forwarded_call_type].to_f		
	end

	def missed_call_cost
		incoming? ? FRESHFONE_CHARGES['MISSED_OR_BUSY'][:incoming].to_f : FRESHFONE_CHARGES['MISSED_OR_BUSY'][:outgoing].to_f
	end

	def supervisor_leg_cost
		FRESHFONE_CHARGES['SUPERVISOR'][:per_participant].to_f
	end

	private

		def call_forwarded?
			return true if forwarded?
			return false if call.meta.blank?
			[ Freshfone::CallMeta::USER_AGENT_TYPE_HASH[:available_on_phone], 
					Freshfone::CallMeta::USER_AGENT_TYPE_HASH[:direct_dial],
					Freshfone::CallMeta::USER_AGENT_TYPE_HASH[:external_transfer]].include?(call.meta.device_type)
		end

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
			self.number = call.direct_dial_number || forwarded_number
			self.country =  fetch_country_code(number)

			return calculate(:outgoing) if outgoing?
			calculate(forwarded_call_type)
		end

		def forwarded_number
			return call.agent.available_number if call.meta.available_on_phone?
			(call.meta.meta_info.is_a?(Hash) ? call.meta.meta_info[:agent_info] : call.meta.meta_info) unless call.meta.blank?
		end

		# MaxLength of the existing numbers  
		# number array is in the order of most digits to less.
		# Matching will check in the same orderly so that we match most digits first
		# Always maintain most digits number first in the array(in freshfone_charges.yml)
		def calculate(call_type)
			self.country =  fetch_country_code(number) if country_invalid?

			calculate_pulse_rate(get_matching_country_cost, call_type) unless country_invalid? #if global country code too is invalid
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

		def ignore_format(number)
			number.gsub(/\D/, '')#returns just the number. hyphens, blank space, leading plus everthing is removed.
		end

		def get_matching_country_cost
			formatted_number = ignore_format(number)
			max_length = FRESHFONE_CHARGES[country][:max_digits]
			max_length.times do |index|
				shortened_number = formatted_number[0..(max_length - index - 1)]
				FRESHFONE_CHARGES[country][:numbers].each_pair do |number_array, source_prefix|
					number_array = number_array.split(',')
					if number_array.include? shortened_number
						return source_prefix['DEFAULT']
					end
				end
			end
		end

		def calculate_pulse_rate(source_prefix_cost, call_type)
			multiplier = cost_multiplier(call_type)
			offset = cost_offset(call_type)
			# source_prefix_cost.each_pair do |prefix, cost|
			# 	return (cost + offset) * multiplier if caller_prefix_match?(prefix)
			# end
			return self.credit = ((source_prefix_cost + offset) * multiplier).round(3)
		end

		def cost_multiplier(call_type)
			FRESHFONE_CHARGES['COST_CONSTANTS'][:multipliers][call_type]
		end

		def cost_offset(call_type)
			return forwarded_offset(call.parent) if external_transfer?
			FRESHFONE_CHARGES['COST_CONSTANTS'][:offset][call_type]
		end

		def external_transfer?
			call_forwarded? && call.parent.present?
		end

		def forwarded_offset(parent)
			self.country = offset_country(parent)
			self.number = offset_number(parent)
			get_matching_country_cost
		end

		def offset_country(parent)
			return parent.caller_country if parent.outgoing?
			parent.freshfone_number.country
		end

		def offset_number(parent)
			return parent.caller_number if parent.outgoing?
			parent.freshfone_number.number
		end

		def caller_prefix_match?(key)
			source_number = ignore_format(call.source_number)
			key.split(',').any? do |prefix|
				source_number.starts_with?(prefix)
			end
		end
end