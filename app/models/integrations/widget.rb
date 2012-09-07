class Integrations::Widget < ActiveRecord::Base
  belongs_to :application
  attr_protected :application_id
  serialize :options, Hash

  def method_missing(meth_name, *args, &block)
    matched = /(.*)_option(=?)/.match(meth_name.to_s)
    if matched.blank?
      super
    elsif matched[2] == "="
      input_key = matched[1]
      self.options = {} if self.options.blank?
      self.options[input_key] = args[0]
    else
      input_key = matched[1]
      self.options[input_key] unless self.options.blank?
    end
  end

  ALLOWED_PAGES = ["helpdesk_tickets_show_page_side_bar", "helpdesk_tickets_show_page_contact_bar", "contacts_show_page_side_bar"]
end
