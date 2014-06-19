module Helpdesk::TagMethods

  def create_tags(tag_list,item)
    add_tag_list= tag_list.split(",").map { |tag| tag.strip}
    add_ticket_tags(add_tag_list,item)
  end

  def update_tags(tag_list, remove_tags, item)
    new_tag_list= tag_list.split(",").map { |tag| tag.strip}
    old_tag_list = item.tags.map{|tag| tag.name.strip }

    add_ticket_tags( new_tag_list.select {|tag| !old_tag_list.include?(tag) },item)
    #Choosing the ones that are not in the old list.
    
    remove_ticket_tags(old_tag_list.select {|tag| !new_tag_list.include?(tag) },item) unless !remove_tags
    #Choosing the ones that are in the old list and not in the new ones.

  end

  def add_ticket_tags(tags_to_be_added, item)
    begin
      tags_to_be_added.each do |tag_string|
        tag = current_account.tags.find_by_name(tag_string) || current_account.tags.new(:name => tag_string)
        item.tags << tag
      end
    rescue ActiveRecord::RecordInvalid => e
    end
  end

  def remove_ticket_tags(tags_to_be_removed,item)
    tags = current_account.tags.find_all_by_name(tags_to_be_removed)
    unless tags.blank?

      tag_uses = current_account.tag_uses.find_all_by_taggable_id_and_tag_id_and_taggable_type(item.id, tags.map{ |tag| tag.id } ,"Helpdesk::Ticket" )
      current_account.tag_uses.destroy tag_uses

    end

  end

end