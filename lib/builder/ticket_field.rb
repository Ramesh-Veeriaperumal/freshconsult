# Class that builds both the ticket_field, flexfield_def_entry.
class Builder::TicketField
  attr_reader :request_params, :account, :ticket_field_def

  NON_MANDATORY_DEFAULT_FALSE_FIELDS = [].freeze
  NON_MANDATORY_DEFAULT_TRUE_FIELDS = [].freeze

  def initialize(request_params, account)
    @request_params = request_params
    @account = account
    @ticket_field_def = account.ticket_field_def
  end

  def build_ticket_field_and_flexifield_def_entry
    ticket_field = account.ticket_fields.build(ticket_field_params)
    ff_def_entry = account.flexifield_def_entries.build(ff_def_entry_params)
    ticket_field.flexifield_def_entry = ff_def_entry
    account.no_of_ticket_fields_built += 1
    ticket_field
  end

  protected

    def ticket_field_params
      common_n_required_fields_hash.merge(type_based_fields_hash).merge(non_mandatory_fields_hash)
    end

    def common_n_required_fields_hash
      {
        name: field_name,
        column_name: column_name,
        flexifield_coltype: required_type,
        ticket_form_id: ticket_field_def.id,
        label: request_params[:label],
        label_in_portal: request_params[:label_for_customers] || request_params[:label],
        field_type: request_params[:type],
        required: input_or_false(request_params[:required_for_agents]),
        description: request_params[:description] || ''
      }
    end

  private

    def type_based_fields_hash
      {}
    end

    def non_mandatory_fields_hash
      fields_hash = customers_related_fields_hash
      self.class::NON_MANDATORY_DEFAULT_FALSE_FIELDS.each { |field| fields_hash[field.to_sym] = input_or_false(request_params[field.to_sym]) }
      self.class::NON_MANDATORY_DEFAULT_TRUE_FIELDS.each { |field| fields_hash[field.to_sym] = input_or_true(request_params[field.to_sym]) }
      fields_hash
    end

    def ff_def_entry_params
      {
        flexifield_def_id: ticket_field_def.id,
        flexifield_name: column_name,
        flexifield_coltype: required_type,
        flexifield_alias: field_name,
        flexifield_order: position
      }
    end

    def customers_related_fields_hash
      if input_not_given_or_false(request_params[:displayed_to_customers])
        fetch_customers_field_hash(false, false, false)
      elsif input_not_given_or_false(request_params[:customers_can_edit])
        fetch_customers_field_hash(true, false, false)
      else
        fetch_customers_field_hash(true, true, request_params[:required_for_customers])
      end
    end

    def field_name
      Helpdesk::TicketField.field_name(request_params['label'], account.id)
    end

    # Race condition.
    def column_name
      @column_name ||= ticket_field_def.first_available_column(required_type)
    end

    # TODO: change. Check if could be changed to someplace like Serializer as method relies on request_params.
    def required_type
      @required_type ||= begin
        type = request_params['type']
        if type.include?('nested_') || type.include?('dropdown')
          'dropdown'
        elsif type.include?('custom_')
          type.gsub('custom_', '')
        elsif type == FlexifieldConstants::ENCRYPTED_FLEXIFIELD_TYPE
          type
        end
      end
    end

    # Race condition.
    def position
      no_of_ticket_fields_built = account.no_of_ticket_fields_built
      @position ||= (position_less_than_no_of_tickets_built(request_params, no_of_ticket_fields_built) ? no_of_ticket_fields_built : request_params['position'])
    end

    def input_not_given_or_false(param)
      param.nil? || param == false ? true : false
    end

    def fetch_customers_field_hash(displayed_to_customers, customers_can_edit, required_for_customers)
      {
        visible_in_portal: displayed_to_customers,
        editable_in_portal: customers_can_edit,
        required_in_portal: input_or_false(required_for_customers)
      }
    end

    def input_or_false(param)
      param || false
    end

    def input_or_true(param)
      param != false
    end

    def position_less_than_no_of_tickets_built(request_params, no_of_ticket_fields_built)
      request_params['position'].nil? || (request_params['position'] >= no_of_ticket_fields_built)
    end
end
