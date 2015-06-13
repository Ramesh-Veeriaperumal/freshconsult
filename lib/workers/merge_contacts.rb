class Workers::MergeContacts
  extend Resque::AroundPerform 
	@queue = "merge_contacts"

  BATCH_LIMIT = 500

  VOTE_OPTIONS = {
    :object     => "votes",
    :poly_type  => "voteable_type", 
    :poly_id    => "voteable_id", 
    :types      => CommunityConstants::VOTEABLE_TYPES
  }

  MONITOR_OPTIONS = {
    :object     => "monitorships",
    :poly_type  => "monitorable_type", 
    :poly_id    => "monitorable_id", 
    :types      => CommunityConstants::MONITORABLE_TYPES
  }

  def self.perform(args)
    @account = Account.current
    begin
      @parent_user = @account.contacts.find_by_id(args["parent"])
      return if @parent_user.nil?
      @children = @account.all_users.contacts.where({:id => args["children"], :string_uc04 => @parent_user.id})
      unless @children.blank?
        Rails.logger.debug "#{"*"*20}Merging contacts #{@children.map(&:id).join(", ")} with #{@parent_user.id}#{"*"*20}"
        move_child_resources_to_parent
        move_if_exists(User::USER_SECONDARY_ATTRIBUTES)
        @children.each(&:save)
        @parent_user.save
      end
    rescue Exception => e
      Rails.logger.debug "The error is  ::: #{e}"
      NewRelic::Agent.notice_error(e, {:description => "Error while merging #{args["children"].join(", ")} with #{args["parent"]} on Account #{@account.id}"})
    end
  end

  private

  def self.move_child_resources_to_parent
    children_ids = @children.map(&:id)
    move_accessory_attributes children_ids
    move_helpdesk_activities children_ids
    move_forum_activities children_ids
  end

  def self.move_accessory_attributes children_ids
    update_by_batches(@account.tag_uses, "taggable_id", ["taggable_id in (?) and taggable_type = 'User'", children_ids])
    move_each_of(["google_contacts", "user_credentials", "mobihelp_devices"], children_ids)
  end

  def self.move_forum_activities children_ids
    move_each_of(["posts", "topics"], children_ids)
    update_communities_meta(children_ids, VOTE_OPTIONS)
    update_communities_meta(children_ids, MONITOR_OPTIONS)
  end

  def self.move_helpdesk_activities children_ids
    update_by_batches(@account.tickets, "requester_id", ["requester_id in (?)", children_ids])
    move_each_of(["notes"], children_ids)
  end

  #Moving relations by batches of 500
  def self.update_by_batches items, dependent_id, conditions
    begin
      records_updated = items.where(conditions).limit(BATCH_LIMIT).update_all({dependent_id.to_sym => @parent_user.id})
    end while records_updated == BATCH_LIMIT
  end

  def self.move_each_of(arr=[], children_ids)
    arr.each do |relation|
      update_by_batches(@account.send(relation), "user_id", ["user_id in (?)", children_ids])
    end
  end

  # We move attributes of target users to the parent user if the parent user does not have it.
  # Then we nullify that attribute for that particular target user alone.
  def self.move_if_exists(user_att)
    user_att.each do |att|
      if @parent_user.send(att).blank?
        related = @children.detect{|i| i.send(att).present?}
        unless related.nil?
          @parent_user.send("#{att}=", related.send(att))
          related.send("#{att}=", nil) unless att == "avatar" 
          #avatar is a has_one relation and hence will error out without the check
        end
      end
    end
  end

  # We are doing this as a user should not have multiple monitorships/votes for the same topic/forum etc.
  # We are moving the ones not present in the parent and deleting the ones that are repeated in the target.
  # We are not moving them in batches due to this
  def self.update_communities_meta children_ids, options
    update_ids, delete_ids = [], []
      options[:types].each do |obj|        
        current_children_objects  = @account.send(options[:object])
                                      .where({:user_id => children_ids, options[:poly_type].to_sym => obj})
        current_parent_object_ids = @parent_user.send(options[:object])
                                      .where({options[:poly_type].to_sym => obj})
                                      .select(options[:poly_id])
                                      .collect{|x| x.send(options[:poly_id])}

        current_children_objects.each do |child|
          if current_parent_object_ids.include(child.send(options[:poly_id])
            delete_ids << child.id
          else
            update_ids << child.id
            current_parent_object_ids << child.send(options[:poly_id])  # If multiple children have votes/mons. for the same poly_id
          end
        end
      end
      @account.send(options[:object]).where({:id => update_ids}).update_all({:user_id => @parent_user.id}) if update_ids.present?
      @account.send(options[:object]).where({:id => delete_ids}).destroy_all if delete_ids.present?
  end
  
end
