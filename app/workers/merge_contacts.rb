class MergeContacts < BaseWorker

  sidekiq_options :queue => :merge_contacts, :retry => 0, :failures => :exhausted

  include RabbitMq::Helper

  BATCH_LIMIT = 500

  VOTE_OPTIONS = {
    :object     => "votes",
    :poly_type  => :voteable_type, 
    :poly_id    => "voteable_id", 
    :types      => CommunityConstants::VOTEABLE_TYPES,
    :user       => :user_id
  }

  MONITOR_OPTIONS = {
    :object     => "monitorships",
    :poly_type  => :monitorable_type, 
    :poly_id    => "monitorable_id", 
    :types      => CommunityConstants::MONITORABLE_TYPES,
    :user       => :user_id
  }

  TAG_OPTIONS = {
    :object     => "tag_uses",
    :poly_type  => :taggable_type,
    :poly_id    => "tag_id",
    :types      => ["User"],
    :user       => :taggable_id
  }

  def perform(args)
    @account = Account.current
    begin
      @parent_user = @account.contacts.find_by_id(args["parent"])
      return if @parent_user.nil?
      @children = @account.all_users.contacts.where({:id => args["children"], :string_uc04 => @parent_user.id})
      unless @children.blank?
        Rails.logger.debug "#{"*"*20}Merging contacts #{@children.map(&:id).join(", ")} with #{@parent_user.id}#{"*"*20}"
        move_child_resources_to_parent
        move_if_exists(user_attributes)
        @children.each(&:save)
        @parent_user.save
      end
    rescue Exception => e
      Rails.logger.debug "The error is  ::: #{e}"
      NewRelic::Agent.notice_error(e, {:description => "Error while merging #{args["children"].join(", ")} with #{args["parent"]} on Account #{@account.id}"})
    end
  end

  private

  def move_child_resources_to_parent
    children_ids = @children.map(&:id)
    move_accessory_attributes children_ids
    move_helpdesk_activities children_ids
    move_forum_activities children_ids
    move_polymorphic_objects children_ids
    move_archived_tickets children_ids if @account.features_included?(:archive_tickets)
  end

  def move_accessory_attributes children_ids
    move_each_of(['google_contacts', 'user_credentials', 'ebay_questions'], children_ids)
  end

  def move_forum_activities children_ids
    move_each_of(["posts", "topics"], children_ids)
  end

  def move_helpdesk_activities children_ids
    if @parent_user.contractor?
      update_by_batches(@account.tickets, 
                        { :owner_id => @parent_user.company_id }, 
                        ["requester_id in (?) and owner_id is null", children_ids])
      update_by_batches(@account.tickets, 
                        { :requester_id => @parent_user.id }, 
                        ["requester_id in (?)", children_ids])
    else
      update_by_batches(@account.tickets, 
                        { :requester_id => @parent_user.id,
                          :owner_id     => @parent_user.company_id }, 
                        ["requester_id in (?)", children_ids])
    end
    move_each_of(["notes"], children_ids)
  end

  def move_polymorphic_objects children_ids
    [MONITOR_OPTIONS, VOTE_OPTIONS, TAG_OPTIONS].each do |options|
      update_polymorphic(children_ids, options)
    end
  end

  def move_archived_tickets(children_ids)
    if @parent_user.contractor?
      update_by_batches(@account.archive_tickets, 
                        { :owner_id => @parent_user.company_id }, 
                        ["requester_id in (?) and owner_id is null", children_ids])
      update_by_batches(@account.archive_tickets, 
                        { :requester_id => @parent_user.id }, 
                        ["requester_id in (?)", children_ids])
    else
      update_by_batches(@account.archive_tickets, 
                        { :requester_id => @parent_user.id,
                          :owner_id     => @parent_user.company_id }, 
                        ["requester_id in (?)", children_ids])
    end
    move_each_of(["archive_notes"], children_ids)
  end

  #Moving relations by batches of 500
  def update_by_batches items, values, conditions
    begin
      items_to_update     = items.where(conditions).limit(BATCH_LIMIT)
      klass_name          = items_to_update.klass.name
      # We are doing update_all to update the user id to the parent user id. update_all won't instantiate active record objects ,
      # but just returns the count. We need to manually push the changes to RMQ as it does not trigger callbacks too.
      # Here adding .all to trigger the query(delayed query) and storing the active record objects for which updates need to be sent to RMQ 
      records_updated     = items_to_update.update_all_with_publish(values, {}, batch_size: BATCH_LIMIT, manual_publish: true)
    end while records_updated == BATCH_LIMIT
  end

  def move_each_of(arr=[], children_ids)
    arr.each do |relation|
      update_by_batches(@account.safe_send(relation), 
                        { :user_id => @parent_user.id }, 
                        ["user_id in (?)", children_ids])
    end
  end

  # We move attributes of target users to the parent user if the parent user does not have it.
  # Then we nullify that attribute for that particular target user alone.
  def move_if_exists(user_att)
    user_att.each do |att|
      if @parent_user.safe_send(att).blank?
        if(att == "mobile" || att == "phone")
          related_children = @children.select{|i| i.safe_send(att).present?}
          @parent_user.safe_send("#{att}=", related_children.first.safe_send(att)) unless related_children.empty?
          related_children.each do |child|
            child.safe_send("#{att}=", nil)
          end
        else
          related = @children.detect{|i| i.safe_send(att).present?}
          unless related.nil?
            @parent_user.safe_send("#{att}=", related.safe_send(att))
            related.safe_send("#{att}=", nil) unless att == "avatar" 
            #avatar is a has_one relation and hence will error out without the check
          end
        end
      end
    end
  end

  def user_attributes
    User::USER_SECONDARY_ATTRIBUTES + @account.contact_form.custom_contact_fields.map(&:name)
  end

  # We are doing this as a user should not have multiple monitorships/votes for the same topic/forum etc.
  # We are moving the ones not present in the parent and deleting the ones that are repeated in the target.
  # We are not moving them in batches due to this
  def update_polymorphic children_ids, options
    update_ids, delete_ids = [], []
    options[:types].each do |obj|        
      current_children_objects  = @account.safe_send(options[:object])
                                    .where({options[:user] => children_ids, options[:poly_type] => obj})
      current_parent_object_ids = @parent_user.safe_send(options[:object])
                                    .where({options[:poly_type] => obj})
                                    .select(options[:poly_id])
                                    .collect{|x| x.safe_send(options[:poly_id])}

      current_children_objects.each do |child|
        if current_parent_object_ids.include?(child.safe_send(options[:poly_id]))
          delete_ids << child.id
        else
          update_ids << child.id
          current_parent_object_ids << child.safe_send(options[:poly_id])  # If multiple children have votes/mons. for the same poly_id
        end
      end
    end
    @account.safe_send(options[:object]).where({:id => update_ids}).update_all_with_publish({ options[:user] => @parent_user.id }, ["#{options[:user]} != ?", @parent_user.id]) if update_ids.present?
    @account.safe_send(options[:object]).where({:id => delete_ids}).destroy_all if delete_ids.present?
  end
end
