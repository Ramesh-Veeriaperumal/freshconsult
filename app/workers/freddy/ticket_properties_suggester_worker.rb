module Freddy
  class TicketPropertiesSuggesterWorker < BaseWorker
    sidekiq_options queue: :ticket_properties_suggester, retry: 5
    include TicketPropertiesSuggester::Util   
    PRODUCT = 'FRESHDESK'.freeze

    def perform(args)         
      args.symbolize_keys!
      account = Account.current
      @ticket = account.tickets.find_by_id(args[:ticket_id])
      url = FreddySkillsConfig[:ticket_properties_suggester][:url] + args[:action]
      api_options = {}
      method_options = {}
      api_options[:header] = { 'Content-Type' => 'application/json' }
      api_options[:body] = { product_name: PRODUCT,
                             account_id: account.id.to_s,
                             ticket_id: @ticket.id.to_s }
      api_options[:timeout] = FreddySkillsConfig[:ticket_properties_suggester][:timeout]
      method_options = args.slice(:dispatcher_set_priority, :model_changes)
      safe_send(args[:action], url, api_options, method_options)
    rescue StandardError => e
      Rails.logger.error "Error in TicketPropertiesSuggesterWorker::Exception:: #{e.message}"
      NewRelic::Agent.notice_error(e, description: "Error in TicketPropertiesSuggesterWorker::Exception:: #{e.message}")
      raise e
    end

    private

      def predict(url, api_options, method_options)                   
        api_options[:body] = api_options[:body].merge!(subject: @ticket.subject, description: @ticket.description).to_json
        parsed_response = {}
        time_taken = Benchmark.realtime { parsed_response = execute_api_call(url, api_options) }
        Rails.logger.info "Time Taken for prediction A - #{Account.current.id} T - #{@ticket.id} time - #{time_taken}"        
        if parsed_response.present? && (parsed_response.is_a? Hash)
          suggested_fields = construct_suggested_fields(parsed_response, method_options)
          ticket_properties_suggester_hash = construct_ticket_properties_suggester_hash(suggested_fields)
          save_ticket_properties_suggester(ticket_properties_suggester_hash)
        end
      end

      def feedback(url, api_options, method_options = {})            
        updated_values = {}
        predicted_values = {}
        suggested_fields = @ticket.schema_less_ticket.ticket_properties_suggester_hash[:suggested_fields]
        method_options[:model_changes].each do |ml_field, value|          
          product_field = ML_FIELDS_TO_PRODUCT_FIELDS_MAP[ml_field.to_sym].to_sym
          case ml_field
          when 'group_id'
            predicted_values[ml_field] = suggested_fields[product_field][:response].to_s
            updated_values[ml_field] = value[1].to_s
          when 'priority'
            predicted_values[ml_field] = TicketConstants::PRIORITY_NAMES_BY_KEY[suggested_fields[product_field][:response]]
            updated_values[ml_field] = TicketConstants::PRIORITY_NAMES_BY_KEY[value[1]]
          when 'ticket_type'
            predicted_values[ml_field] = suggested_fields[product_field][:response]
            updated_values[ml_field] = value[1]
          end
        end
        api_options[:body] = api_options[:body].merge!(updated_values: updated_values, predicted_values: predicted_values).to_json
        execute_api_call(url, api_options)
      end

      def execute_api_call(url, options)
        http_response = HTTParty.post(url, options)
        parsed_response = http_response.parsed_response
        Rails.logger.info "API options = #{options.inspect} parsed_response = #{parsed_response.inspect}"
        parsed_response
      end

      def construct_suggested_fields(parsed_response, method_options)
        suggested_fields = parsed_response.each_with_object({}) do |(ml_field, value), hash|
          product_field = ML_FIELDS_TO_PRODUCT_FIELDS_MAP[ml_field.to_sym]
          value['updated'] = @ticket.safe_send(product_field).present? ? true : false
          value['response'] = transform_value(product_field, value['response']) if entity_exists?(product_field, value['response'])
          hash[product_field] = value
        end
        suggested_fields['priority']['updated'] = priority_updated?(method_options) if suggested_fields['priority'].present?
        suggested_fields = suggested_fields.deep_symbolize_keys
      end

      def construct_ticket_properties_suggester_hash(suggested_fields)
        ticket_properties_suggester_hash = {}
        ticket_properties_suggester_hash[:suggested_fields] = suggested_fields
        ticket_properties_suggester_hash[:expiry_time] = Time.now.to_i + FreddySkillsConfig[:ticket_properties_suggester][:expiry_in_days].days.to_i       
        ticket_properties_suggester_hash = ticket_properties_suggester_hash.deep_symbolize_keys
      end     

      def entity_exists?(product_field, value)
        case product_field
        when 'ticket_type'
          ticket_type = Account.current.ticket_fields.find_by_name('ticket_type')
          picklist_value = ticket_type.picklist_values.find_by_value(value) if ticket_type.present?
          picklist_value.present?
        when 'group'
          Account.current.groups.find_by_id(value.to_i).present?
        else
          true
        end
      end

      def transform_value(field, val)
        case field.to_s
        when 'group'
          val.to_i
        when 'priority'
          TicketConstants::PRIORITY_KEYS_BY_TOKEN[val.downcase.to_sym]
        else
          val
        end
      end

      def save_ticket_properties_suggester(ticket_properties_suggester_hash)
        @ticket.schema_less_ticket.ticket_properties_suggester_hash = ticket_properties_suggester_hash
        @ticket.schema_less_ticket.save!
      end

      def priority_updated?(method_options)
        method_options[:dispatcher_set_priority] || @ticket.priority != TicketConstants::PRIORITY_KEYS_BY_TOKEN[:low]
      end
  end
end
