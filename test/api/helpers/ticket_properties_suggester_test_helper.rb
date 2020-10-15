module TicketPropertiesSuggesterTestHelper

  class ResponseStub
    def initialize(parsed_response, code)
      @parsed_response = parsed_response
      @code = code
    end
    attr_accessor :parsed_response, :code
  end

  def create_ticket_for_ticket_properties_suggester
    a = Account.current
    o = [('a'..'z'), ('A'..'Z')].map { |i| i.to_a }.flatten
    sub = (0...50).map { o[rand(o.length)] }.join
    desc = (0...50).map { o[rand(o.length)] }.join
    cc_emails =  []
    fwd_emails = []
    ticket = Helpdesk::Ticket.new(
        :account_id => a.id,
        :subject => sub,
        :ticket_body_attributes => {:description => desc, :description_html => desc},
        :email => "sales@gmail.com",
        :source => Helpdesk::Source::PHONE,
        cc_email: Helpdesk::Ticket.default_cc_hash.merge(cc_emails: cc_emails, fwd_emails: fwd_emails),
      )
      ticket.save_ticket!
      ticket
    end

    def dispatcher_rule
      rule = VaRule.new
      rule.name = "something"
      rule.condition_data = {:any=>[{:evaluate_on=>:ticket, :name=>"subject", :operator=>"is", :value=>"testing"}]}
      rule.action_data = [{:name=>"group_id", :value=>4}]
      rule.save
    end

    def enable_ticket_properties_suggester
      account = Account.current
      account.add_feature(:ticket_properties_suggester_eligible)
      acc.add_feature(:ticket_properties_suggester)
    end

    def ticket_properties_suggester_json
      { 'priority' => { 'response' => 'Medium', 'conf' => 'high' },
        'ticket_type' => { 'response' => "L1 - How To's", 'conf' => 'high' },
        'group_id' => { 'response' => '246803', 'conf' => 'high' }
      }
    end

    def keys_present?(keys, response)
      keys.reject { |key| response.has_key?(key) }.blank?
    end

    def keys_absent?(keys, response)
      keys.select { |key| response.has_key?(key) }.blank?
    end

     def ticket_field_suggestions(ticket)
      @ticket_field_suggestions = { ticket_field_suggestions: {} }
      ticket_properties_suggester_hash = ticket.schema_less_ticket.ticket_properties_suggester_hash
      return if ticket_properties_suggester_hash.blank?

      expiry_time = ticket_properties_suggester_hash[:expiry_time]
      current_time = Time.now.to_i
      return if expiry_time - current_time < 0

      ret_hash = ticket_properties_suggester_hash[:suggested_fields].each_with_object({}) do |(field, value), hash|
        hash[field] = value[:response] unless value[:updated]
      end
      @ticket_field_suggestions = { ticket_field_suggestions: ret_hash }
      
      JSON.parse(@ticket_field_suggestions.to_json)
    end    
end
