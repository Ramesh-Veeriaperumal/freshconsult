class NotificationPreview
  attr_accessor :account, :body, :user, :ticket_custom_fields, :contact_fields, :company_fields, :message_preview_hash

  AGENT_NAME_PLACEHOLDERS     = ["ticket.agent.name", "agent.name", "ticket.internal_agent.name"]
  AGENT_EMAIL_PLACEHOLDERS    = ["ticket.agent.email", "agent.email", "ticket.internal_agent.email"]
  HELPDESK_NAME_PLACEHOLDERS  = ["helpdesk_name", "ticket.portal_name", "portal_name", "ticket.portal_name"]

  def initialize account = Account.current, user = User.current
    @account              = account
    @user                 = user
    @ticket_custom_fields = load_ticket_custom_fields
    @contact_fields       = load_customer_custom_fields
    @company_fields       = load_company_custom_fields
    @message_preview_hash = generate_message_preview_hash
  end

  def notification_preview(body = "")
    parse_preview body
  end

  def add_custom_preview_hash(hash)
    @message_preview_hash.merge!(hash)
  end

  private

  def load_ticket_custom_fields
    account.ticket_fields_from_cache.select{|field| (field.flexifield_def_entry_id.present?)}.inject({}) do |hash, custom_field|
      parsed_value = "ticket.#{custom_field.name[0...custom_field.name.rindex('_')]}"
      hash[parsed_value] = "(#{parsed_value})"
      hash
    end
  end

  def load_customer_custom_fields
    account.contact_form.custom_contact_fields.inject({}) do |hash, custom_field|
      parsed_value = "ticket.requester.#{custom_field.name[3..-1]}"
      hash[parsed_value] = "(#{parsed_value})"
      hash
    end
  end

  def load_company_custom_fields
    account.company_form.custom_company_fields.inject({}) do |hash, custom_field|
      parsed_value = "ticket.company.#{custom_field.name[3..-1]}"
      hash[parsed_value] = "(#{parsed_value})"
      hash
    end
  end

  def generate_message_preview_hash
    merged_hash = {}
    merged_hash.merge!(MESSAGE_PREVIEW_DATA)
    merged_hash.merge!(ticket_custom_fields).merge!(contact_fields).merge!(company_fields)
    AGENT_NAME_PLACEHOLDERS.each do |placeholder|
      merged_hash[placeholder] = User.current.name
    end
    AGENT_EMAIL_PLACEHOLDERS.each do |placeholder|
      merged_hash[placeholder] = User.current.email
    end
    HELPDESK_NAME_PLACEHOLDERS.each do |placeholder|
      merged_hash[placeholder] = account.helpdesk_name
    end
    merged_hash
  end

  def parse_preview(notification_body)
    return "" if notification_body.blank?
    place_holders    = notification_body.scan(/\{{(.*?)\}}/).uniq
    place_holders.each do |p|
      placeholder = p.to_s
      new_value = ""
      if message_preview_hash[placeholder].present?
        new_value = message_preview_hash[placeholder].to_s
        new_value = new_value.gsub("<yourdomain>.freshdesk.com", (Portal.current.present? ? Portal.current.host : Account.current.host))
        new_value = new_value.gsub("<current agent’s name>", User.current.name)
      end
      notification_body = notification_body.gsub('{{' + placeholder + '}}', new_value)
    end
    Helpdesk::HTMLSanitizer.clean(notification_body)
  end

end
