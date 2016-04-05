module Helpdesk::TagMethods

  def update_tags(tag_list, remove_tags, item)
    new_tag_list= tag_list.split(",").map { |tag| tag.strip.downcase}
    old_tag_list = item.tags.map{|tag| tag.name.strip.downcase }

    add_ticket_tags( new_tag_list.select {|tag| !old_tag_list.include?(tag) },item)
    #Choosing the ones that are not in the old list.
    
    remove_ticket_tags(old_tag_list.select {|tag| !new_tag_list.include?(tag) },item) unless !remove_tags
    #Choosing the ones that are in the old list and not in the new ones.

    update_ticket_in_es(item) if (tag_list.present? and Account.current.launched?(:es_count_writes))
  end

  def add_ticket_tags(tags_to_be_added, item)
    tags_to_be_added.each do |tag_string|
      tag = Account.current.tags.find_by_name(tag_string) || Account.current.tags.new(:name => tag_string)
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
                                                  :version_value => Search::Job.es_version
                                                })
  end

  def store_dirty_tags item
    if item.is_a?(Helpdesk::Ticket)
      item.dirty_attributes[:tag_attributes] = {}
      item.tags.each do |tag|
        item.dirty_attributes[:tag_attributes].merge!(tag.id => tag.name)
      end
      item.tags = []
    end
  end

  def restore_dirty_tags item 
    if item.is_a?(Helpdesk::Ticket)
      unless item.deleted? or item.spam?
        item.dirty_attributes[:tag_attributes].each do |key, value|
            tag = Account.current.tags.find_by_id(key)
            if tag 
              item.tags << tag 
            else
              item.tags << Account.current.tags.new(:name => value, :tag_uses_count => 1)
            end
          end
          item.dirty_attributes[:tag_attributes] = {}
      end
    end
  end


  # Used by API v2
  def sanitize_tags(tags)
    Array.wrap(tags).map! { |x| RailsFullSanitizer.sanitize(x.to_s.strip) }.uniq(&:downcase).reject(&:blank?)
  end

  def construct_tags(tags_to_be_added)
    tag_list = []
    # add tags to the item which already exists
    # not using cache as the tags can be added more often. Hence using cache will result in full array. 
    existing_tags = current_account.tags.where(:name => tags_to_be_added)
    tag_list.push(*existing_tags)
    # Collect new tags to be added
    existing_tag_names = tag_list.collect(&:name)
    tags_to_be_added.each do |tag|
      tag_list << current_account.tags.new(:name => tag) unless existing_tag_names.any?{ |x| x.casecmp(tag).zero? }
    end
    tag_list
  end

end