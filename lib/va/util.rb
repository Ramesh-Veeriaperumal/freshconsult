module Va::Util

	def zendesk_import?
		Thread.current["zenimport_#{account_id}"]
	end

	def freshdesk_webhook?
		Thread.current[:http_user_agent] == 'Freshdesk'
	end

  def customer_import?
    Thread.current["customer_import_#{account_id}"]
  end

  def map_class class_name
    attr_map = {"Helpdesk::Ticket" => "ticket", "User" => "user", "Helpdesk::Note" => "note", "Company" => "company"}
    attr_map[class_name]
  end
	
end