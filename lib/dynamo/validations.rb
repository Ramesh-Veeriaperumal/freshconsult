module Dynamo::Validations

	def valid?
		@errors.clear
		return_value = (hash_valid? && range_valid? && lsi_valid?)
		clear_empty_errors
		return_value
	end

	def errors
		@errors
	end

	protected

		def hash_valid?
			reqd_key_errors(@hash).blank?
		end

		def range_valid?
			return true if @range.blank?
			reqd_key_errors(@range).blank?
		end

		def lsi_valid?
			((@local_secondary_indices || []).map do |index|
				@errors[index[:name]] = ["Invalid Type"] unless valid_type?(index, true)
			end).compact.empty?
		end

		def clear_empty_errors
			@errors.delete_if { |k, v| v.blank? }
		end

		def reqd_key_errors(key)
			@errors[key[:name]] = [
				("Value required" unless @attributes[key[:name]].present?),
				("Invalid Type" unless valid_type?(key))
			].compact
		end

		def valid_type?(key, lsi=false)
			return true if lsi && @attributes[key[:name]].blank?
			klass_arr = Dynamo::TYPE_CLASS_MAPPING[key[:type]]
			valid_type = @attributes[key[:name]].is_a?(klass_arr[0])
			valid_type && (klass_arr[1].blank? || !type_mismatch?(@attributes[key[:name]], klass_arr[1]))
		end

		def type_mismatch?(arr, data_type)
			arr.map { |v| v.is_a? data_type }.include?(false)
		end
end