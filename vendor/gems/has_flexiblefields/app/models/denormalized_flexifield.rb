class DenormalizedFlexifield < ActiveRecord::Base
  self.primary_key = :id

  include FlexifieldConstants

  MAX_RETRY = 5

  belongs_to_account

  belongs_to :flexifield_def
  belongs_to :flexifield

  attr_protected :account_id, :flexifield_id
  # attr_accessor :previous_attribute_changes

  after_initialize :set_default_values, :set_state_variables
  # before_validation :run_through_validations
  after_commit :set_state_variables, :set_changes_variables

  SERIALIZED_DB_COLUMNS.each do |db_column|
    serialize db_column

    define_method db_column do |display_warn = true|
      display_warning if @warn && display_warn
      read_attribute(db_column)
    end

    define_method "#{db_column}=" do |new_value|
      display_warning
      super(new_value)
    end
  end

  SERIALIZED_COLUMN_MAPPING_BY_ATTRIBUTES.each do |attribute, db_column|
    define_method attribute do
      safe_send(db_column, false)[attribute]
    end

    define_method "#{attribute}=" do |new_value|
      current_value = safe_send(attribute) # self.current_state[db_column][attribute]
      new_value = sanitize_value(db_column, new_value) unless new_value.nil?
      if current_value != new_value
        if new_value.nil?
          safe_send(db_column, false).delete(attribute)
        else
          safe_send(db_column, false)[attribute] = new_value
        end
        current_state[db_column.to_sym][attribute.to_sym] = new_value
        attribute_changes[attribute] = [@load_state[attribute], new_value]
        serialized_changes[db_column] = [nil, current_state[db_column]]
      end
    end
  end

  def deserialized_attributes
    attributes.deep_dup.each_with_object({}) do |(attribute, value), attrs|
      if value.is_a? Hash
        attrs.merge!(value) if value.present?
      else
        attrs[attribute] = value
      end
    end
  end

  def previous_attribute_changes
    @previous_attribute_changes ||= {}
  end

  def attribute_changes
    @attribute_changes ||= {}
  end

  def destroy(*)
    retry_count = 0
    begin
      super
    rescue ActiveRecord::StaleObjectError => e
      retry_count += 1
      if retry_count <= MAX_RETRY
        reload
        retry
      else
        Rails.logger.debug "DenormalizedFlexifield Destroy failed. #{inspect}"
        raise e
      end
    end
  end

  private

    # helps in changes calculation
    def set_default_values
      CREATED_SERIALIZED_COLUMNS.each do |db_column|
        write_attribute(db_column, {}) if respond_to?(db_column) && safe_send(db_column).nil?
      end
      @warn = true
    end

    def set_changes_variables
      @previous_attribute_changes = attribute_changes
      @attribute_changes = {}
    end

    def set_state_variables
      @load_state = deserialized_attributes.with_indifferent_access # works as we dont have arrays
      # Marshal.load(Marshal.dump(self.attributes)).with_indifferent_access #for deep cloning #need to check on security issues
      # @current_state = self.attributes.with_indifferent_access
    end

    def display_warning
      warning_message = 'Only use ticket.flexifield_name= to set value. Setting denormalized value this way will not calculate changes, and hence will not be sanitized, validated and not be part of ticket model changes'
      puts warning_message
      Rails.logger.warn warning_message
    end

    def sanitize_value(db_column, value)
      SERIALIZED_COLUMN_SANITIZATION_BY_DB_COLUMN[db_column].each do |method|
        value = safe_send(method, value)
      end
      value
    end

    def trim_length_of_slt(value)
      value.to_s[0...SLT_CHARACTER_LENGTH]
    end

    def trim_length_of_mlt(value)
      value.to_s[0...MLT_CHARACTER_LENGTH]
    end

    def update(*)
      retry_count = 0
      begin
        super
      rescue ActiveRecord::StaleObjectError => e
        retry_count += 1
        if retry_count <= MAX_RETRY
          @non_serialized_changes = changes
          reload
          reapply_values
          retry
        else
          Rails.logger.debug "DenormalizedFlexifield Save failed. #{inspect}"
          raise e
        end
      end
    end

    def reapply_values
      @non_serialized_changes.merge(serialized_changes).symbolize_keys.each do |db_column, db_value|
        if SERIALIZED_DB_COLUMNS.include?(db_column)
          current_state[db_column].each do |col_name, value|
            safe_send("#{col_name}=", value)
          end
        elsif ![:updated_at, :created_at, :id, :flexifield_id, :account_id].include?(db_column)
          safe_send("#{db_column}=", db_value[1])
        end
      end
    end

    def current_state
      @current_state ||= Hash.new { |h, k| h[k] = {} }
    end

    def serialized_changes
      @serialized_changes ||= {}
    end

  # def run_through_validations
  #   attribute_changes.each do |attribute, new_value|
  #     db_column = SERIALIZED_COLUMN_MAPPING_BY_ATTRIBUTES[attribute]
  #     SERIALIZED_COLUMN_VALIDATION_BY_DB_COLUMN[db_column].each do |method|
  #       safe_send(method, attribute, value)
  #     end
  #   end
  # end

  # def add_attribute_error attribute, error_label, error_message
  #   self.errors.add(attribute.safe_send(error_label), error_message)
  # end

  # def convert_to_integer value
  #   value.to_i
  # end

  # def convert_to_decimal value
  #   value.to_f
  # end

  # def update(*)
  #   if changes_of_serialized_attributes.present?
  #     # | (attributes.keys & self.class.serialized_attributes.keys - SERIALIZED_DB_COLUMNS.map(&:to_s))
  #     super(changed)
  #     @previous_state = cloned_attributes
  #   end
  # end
end
