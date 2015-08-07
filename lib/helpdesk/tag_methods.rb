module Helpdesk::TagMethods

  def create_tags(tag_list,item)
    add_tag_list= tag_list.split(",").map { |tag| tag.to_s.strip}
    add_ticket_tags(add_tag_list,item)
  end

  def update_tags(tag_list, remove_tags, item)
    new_tag_list= tag_list.split(",").map { |tag| tag.to_s.strip}
    old_tag_list = item.tags.map{|tag| tag.name.strip }

    add_ticket_tags( new_tag_list.select {|tag| !old_tag_list.include?(tag) },item)
    #Choosing the ones that are not in the old list.
    
    remove_ticket_tags(old_tag_list.select {|tag| !new_tag_list.include?(tag) },item) unless !remove_tags
    #Choosing the ones that are in the old list and not in the new ones.
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

  def remove_api_ticket_tags(tags,item)
    tag_uses = item.tag_uses.tags_to_remove(item.id, tags.map(&:id), "Helpdesk::Ticket")
    item.tag_uses.destroy tag_uses
    item.tags.reject!{|tag| tags.include?(tag)}
  end

  def api_update_ticket_tags(tags_to_be_added, item)
    old_tags = item.tags
    old_tag_list = old_tags.map{|tag| tag.name.strip }

    new_tag_list = tags_to_be_added - old_tag_list
    api_add_ticket_tags(new_tag_list, item) if new_tag_list.present?
    #Choosing the ones that are not in the old list.
    
    stale_tags = old_tags.select{|x| tags_to_be_added.exclude?(x.name.strip)}
    remove_api_ticket_tags(stale_tags, item) unless stale_tags.empty?
    #Choosing the ones that are in the old list and not in the new ones.
  end

  def api_add_ticket_tags(tags_to_be_added, item)
    # add tags to the item which already exists
    # not using cache as the tags can be added more often. Hence using cache will result in full array. 
    existing_tags = current_account.tags.where(:name => tags_to_be_added)
    item.tags.push(*existing_tags)
    # Collect new tags to be added
    new_tags = tags_to_be_added - existing_tags.collect(&:name)
    new_tags.each do |tag_string|
      # create new tag and add to the item
      item.tags << current_account.tags.new(:name => tag_string)
    end
  end

end