class Workers::MergeContacts
  extend Resque::AroundPerform 
	@queue = "zendeskImport"

  def self.perform(args)
    account = Account.current
    @source_user = account.users.find(args[:source])
    @target_users = account.users.find(:all, :conditions => {:id => args[:targets]})
    move_target_resources_to_source
    move_if_exists("twitter_id", "avatar", "time_zone", "phone", "mobile", "fb_profile_id", "address")
    @target_users.each do |target|
      target.parent_id = @source_user.id
      target.update_attributes(:deleted => true, :email => nil)
    end
  end

  def self.move_target_resources_to_source
    @target_users.each do |target|
      target.tickets.update_all(:requester_id =>  @source_user.id)
      target.notes.update_all(:user_id =>  @source_user.id)
      target.activities.update_all(:user_id =>  @source_user.id)
      target.tag_uses.update_all(:taggable_id => @source_user.id)
      target.google_contacts.update_all(:user_id => @source_user.id)
      # target.votes.update_all(:user_id => @source_user.id)
      # target.topics.update_all(:user_id => @source_user.id)
      # target.posts.update_all(:user_id => @source_user.id)
      # target.monitorships.update_all(:user_id => @source_user.id)
      # target.moderatorships.update_all(:user_id => @source_user.id)
    end
  end

  def self.move_if_exists(*user_att)
    user_att.each { |att|
      if @source_user.send(att).blank?
        related = @target_users.select{|i| i unless i.send(att).blank?}
        @source_user.update_attribute(att, related.first.send(att)) unless related.first.nil?
        @target_users.each{|x| x.send("#{att}=", nil)}
      end
    }
  end
  
end