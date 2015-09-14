module Helpdesk::TagMethods

  def create_tags(tag_list,item)
    add_tag_list= tag_list.split(",").map { |tag| tag.strip}
    add_ticket_tags(add_tag_list,item)
    # update_ticket_in_es(item) #=> Ticket ID won't be available as save not happened. Skip this scenario until phase-1?
  end

  def update_tags(tag_list, remove_tags, item)
    new_tag_list= tag_list.split(",").map { |tag| tag.strip}
    old_tag_list = item.tags.map{|tag| tag.name.strip }

    add_ticket_tags( new_tag_list.select {|tag| !old_tag_list.include?(tag) },item)
    #Choosing the ones that are not in the old list.
    
    remove_ticket_tags(old_tag_list.select {|tag| !new_tag_list.include?(tag) },item) unless !remove_tags
    #Choosing the ones that are in the old list and not in the new ones.

    update_ticket_in_es(item) if Account.current.launched?(:es_count_writes)
  end

  def add_ticket_tags(tags_to_be_added, item)
    tags_to_be_added.each do |tag_string|
      tag = current_account.tags.find_by_name(tag_string) || current_account.tags.new(:name => tag_string)
      item.tags << tag
    end
    rescue Exception => e
      NewRelic::Agent.notice_error(e) 
  end

  def remove_ticket_tags(tags_to_be_removed,item)
    tags = item.tags.find_all_by_name(tags_to_be_removed)
    unless tags.blank?
        tag_uses = item.tag_uses.tags_to_remove(item.id, tags.map{ |tag| tag.id }, "Helpdesk::Ticket")
        item.tag_uses.destroy tag_uses
    end
  end

  # Couldn't find a better place or cleaner way to do this.
  def update_ticket_in_es(ticket)
    SearchSidekiq::TicketActions::DocumentAdd.perform_async({ 
                                                  :klass_name => 'Helpdesk::Ticket', 
                                                  :id => ticket.id,
                                                  :version_value => Time.now.to_i
                                                })
  end

  def construct_tags(tags_to_be_added)
    tag_list = []
    # add tags to the item which already exists
    # not using cache as the tags can be added more often. Hence using cache will result in full array. 
    existing_tags = current_account.tags.where(:name => tags_to_be_added)
    tag_list.push(*existing_tags)
    # Collect new tags to be added
    new_tags = tags_to_be_added - existing_tags.collect(&:name)
    new_tags.each do |tag_string|
      # create new tag and add to the item
      tag_list << current_account.tags.new(:name => tag_string)
    end
    tag_list
  end

end