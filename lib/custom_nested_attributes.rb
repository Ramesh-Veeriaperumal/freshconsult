class CustomNestedAttributes

	def initialize list, account
    list = list.split(",") if list.is_a? String
    @list    = list
    @account = account || Account.current
	end

  def helpdesk_permissible_domains_attributes
    return [] if @list.blank?
    existing_domains = select_from_existing_helpdesk_domains @list
    
    removed_domains = helpdesk_permissible_domains_list - @list
    removed_domains_attributes = build_nested_attributes(select_from_existing_helpdesk_domains(removed_domains), :domain, true)

    new_domains = @list - helpdesk_permissible_domains_list
    new_domains_attributes = build_new_nested_attributes(new_domains, :domain)

    new_domains_attributes + removed_domains_attributes
  end

  private

  def select_from_existing_helpdesk_domains domains
    @account.helpdesk_permissible_domains.where(:domain => domains).select("id, domain")
  end

  def helpdesk_permissible_domains_list
    @permissible_domains ||= @account.helpdesk_permissible_domains.pluck(:domain)
  end

  def build_nested_attributes items, attribute, destroy = false
    items.inject([]) do |collection, item|
      collection << {:id => item.id, attribute => item[attribute], :_destroy => destroy}
    end
  end

  def build_new_nested_attributes items, attribute
    items.inject([]) do |collection, item|
      collection << {:id => nil, attribute => item }
    end    
  end

end