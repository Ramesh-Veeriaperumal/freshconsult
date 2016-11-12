module Va::Util

	include Redis::MarketplaceAppRedis

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

  def sent_for_enrichment?
    # Marketplace Apps: Dispatcher is delayed. So any update actions that trigger observer events should be skipped till the dispatcher is run
  	(self.class == Helpdesk::Ticket) && queued_for_marketplace_app?(self.account_id, self.display_id) && Account.current.skip_dispatcher?
  end
	
end