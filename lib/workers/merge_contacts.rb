class Workers::MergeContacts
  extend Resque::AroundPerform 
	@queue = "merge_contacts"


  BATCH_LIMIT = 500

  def self.perform(args)
    account = Account.current
    @source_user = account.users.find(args[:source])
    @target_users = account.all_users.find(:all, :conditions => {:id => args[:targets]})
    move_target_resources_to_source(account)
    move_if_exists(User::USER_SECONDARY_ATTRIBUTES)
    @source_user.save
    @target_users.each do |target|
      target.parent_id = @source_user.id
      target.save
    end
  end

  private

  def self.move_target_resources_to_source account
    #Should be updated to .where(conditions).update_all(update to) in rails 3
    targets = @target_users.map(&:id)
    update_by_batches(account.tickets, "requester_id", ["requester_id in (?)", targets])
    update_by_batches(account.notes, "user_id", ["user_id in (?)", targets])
    update_by_batches(account.activities, "user_id", ["user_id in (?)", targets])
    update_by_batches(account.tag_uses, "taggable_id", ["taggable_id in (?) and taggable_type = 'User'", targets])
    update_by_batches(GoogleContact, "user_id", ["user_id in (?)", targets])
  end

  def self.update_by_batches items, dependent_id, conditionals
    begin
      records_updated = items.update_all({dependent_id.to_sym => @source_user.id}, conditionals, {:limit => BATCH_LIMIT})
    end while records_updated == BATCH_LIMIT
  end

  def self.move_if_exists(user_att)
    user_att.each do |att|
      if @source_user.send(att).blank?
        related = @target_users.detect{|i| i.send(att).blank?}
        @source_user.send("#{att}=", related.send(att)) unless related.nil?
        @target_users.each{|x| x.send("#{att}=", nil)}
      end
    end
  end
  
end