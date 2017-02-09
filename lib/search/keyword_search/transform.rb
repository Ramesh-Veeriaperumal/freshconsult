# Advanced search transformation module
#
class Search::KeywordSearch::Transform
    
  DEFAULT_FIELDS = [
    'requester_id', 'responder_id', 'group_id', 'status', 'priority', 'type', 'source', 'tags', 'company_id', 'product'
  ]

  DATE_FIELDS = [ 'created_at', 'due_by' ]

  def initialize(filter_hash)
    @filter_params  = filter_hash.dclone
    @date_keys      = (DATE_FIELDS & @filter_params.keys)
    @cf_strkeys     = (@filter_params.keys & custom_string_fields.values)
    @cf_boolkeys    = (@filter_params.keys & custom_boolean_fields.values)
  end
  
  def transform
    parameters = Hash.new.tap do |searchparams|
      DEFAULT_FIELDS.each do |field|
        searchparams["filter_#{field}"] = @filter_params[field].to_s.split(',').map(&:squish).compact.uniq.join('","')
      end

      # Using .values/.keys depends on whether UI is passing ffs_01/field_1
      #
      searchparams["filter_cf_str"] = Array.new.tap do |cf_params|
        @cf_strkeys.each do |field|
          cf_params.push({
            cf_key: field,
            cf_val: @filter_params[field].to_s.split(',').map(&:squish).compact.uniq.join('","')
          })
        end
      end if 
      #
      searchparams["filter_cf_bool"] = Array.new.tap do |cf_params|
        @cf_boolkeys.each do |field|
          cf_params.push({
            cf_key: field,
            cf_val: @filter_params[field]
          })
        end
      end
      
      @date_keys.each do |field|
        searchparams["filter_#{field}"] = process_date_value(@filter_params[field].to_s)
      end
    end

    parameters
  end
  
  private
    
    # Dates need to reconstructed into timestamp in ISO8601 format
    #
    def process_date_value(start_date)
      Time.zone.parse(start_date).utc.iso8601
      # date_value = Time.zone.now.utc.iso8601
      # Time.use_zone(Account.current.time_zone) do
      #   case value
      #   when 'today'
      #     date_value = Time.zone.now.beginning_of_day.utc.iso8601
      #   when 'yesterday'
      #     date_value = Time.zone.now.yesterday.beginning_of_day.utc.iso8601
      #   when 'week'
      #     date_value = Time.zone.now.beginning_of_week.utc.iso8601
      #   when 'last_week'
      #     date_value = Time.zone.now.beginning_of_day.ago(7.days).utc.iso8601
      #   when 'month'
      #     date_value = Time.zone.now.beginning_of_month.utc.iso8601
      #   end
      # end
      # date_value
    end

    def custom_fields
      @custom_field_mapping ||= Account.current.ticket_field_def.ff_alias_column_mapping.select {
                                  |field_alias, field_name| field_name =~ /^ff(s|_boolean)/
                                }
    end

    def custom_string_fields
      @custom_str ||= custom_fields.select { |field_alias, field_name| field_name =~ /^ffs/ }
    end

    def custom_boolean_fields
      @custom_bool ||= custom_fields.select { |field_alias, field_name| field_name =~ /^ff_boolean/ }
    end
  
end