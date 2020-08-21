class DenormalizedFlexifield < ActiveRecord::Base
  self.primary_key = :id

  include FlexifieldConstants
  include Helpdesk::EncryptedField

  MAX_RETRY = 5

  belongs_to_account

  belongs_to :flexifield_def
  belongs_to :flexifield

  attr_protected :account_id, :flexifield_id

  after_initialize :set_default_values, :set_state_variables
  after_commit :set_state_variables, :set_changes_variables

  SERIALIZED_DB_COLUMNS.each do |db_column|
    serialize db_column, Hash

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
      begin
        db_value = safe_send(db_column, false)
        sanitize_value(db_column, db_value[attribute], true)
      rescue Exception => e
        Rails.logger.debug "DenormalizedFlexifield Exception, ID: #{self.id}, Message: #{e.message}, db_value: #{db_value.inspect}, db_value class: #{db_value.class.name} attribute: #{attribute}, db_column: #{db_column}"
        nil
      end
    end

    define_method "#{attribute}=" do |new_value|
      current_value = safe_send(attribute) # self.current_state[db_column][attribute]
      if current_value != new_value
        if new_value.nil?
          safe_send(db_column, false).delete(attribute)
        else
          new_value = sanitize_value(db_column, new_value)
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

    def sanitize_value(db_column, value, read = false)
      sanitization_methods_hash = read ? SERIALIZED_COLUMN_READ_SANITIZATION_BY_DB_COLUMN : SERIALIZED_COLUMN_WRITE_SANITIZATION_BY_DB_COLUMN
      sanitization_methods_hash[db_column].each do |method|
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
          ### Fires select ... for update query
          ### Doesn't prevent other mysql clients from reading the record
          ### Any updates or other select ... for update to this record will wait till the end of this transaction
          ### calling reload doesn't fetch the latest values from DB, because of either of 
          ###    - Activerecord querycache (Activerecord returns the loaded values when a query is hit again) - This has been fixed in latest AR versions. We haven't enabled it though. Use `self.class.connection.clear_query_cache` to fix this
          ###    - Mysql query cache (We haven't enabled it)
          ###    - Mysql transaction isolation level set to `REPEATABLE-READ `(default value set by mysql) which loads the same values previously loaded inside a transaction (the issue we are addressing here, this will also solve for the above two as it is a different query - including ... for update. This also loads the latest values despite transaction isolation levels)
          ### Throws `ActiveRecord::StatementInvalid: Mysql2::Error: Lock wait timeout exceeded; try restarting transaction` when another transaction holds this record beyond timeout. `deadlock_retry` gem handles retrying and this error is thrown after retrying 3 times(defined inside gem - MAXIMUM_RETRIES_ON_DEADLOCK). *** Should we rescue this? ***
          ### Using select ... for update outside the transaction will not have any effect
          ### Tried nested transactions. Mysql doesn't natively support this as it does `Implicit Commit`, but can be done as a workaround by checking out a different connection from AR connection pool, initiate a new transaction, use that to fire select ... for update query and checkin the connection back to connection pool. AR doesn't return a different connection while checkout, have to reset the current connection, fetch one and set the old connection back. Unsure how thread safe it is & how exceptions will be propagated. Sample code commented below #new_connection method
          ### Possible other way to fix this - move to json columns, AR doesn't support key wise updating of json
          lock!
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
end
