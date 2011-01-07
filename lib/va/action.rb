class Va::Action
  attr_accessor :action_key, :act_hash
  
  def initialize(act_hash)
    @act_hash = act_hash
    @action_key = act_hash[:action]
  end
  
  def value
    act_hash[:value]
  end
  
  def trigger(act_on)
    return send(action_key, act_on) if respond_to?(action_key)
    return act_on.send("#{action_key}=", value) if act_on.respond_to?("#{action_key}=")
    
    puts "From the trigger of Action... Looks like #{action_key} is not supported!"
  end
  
  protected
    def add_tag(act_on)
      value.split(',').each do |tag_name|
        tag_name.strip!
        tag = Helpdesk::Tag.find_by_name_and_account_id(tag_name, act_on.account_id) || Helpdesk::Tag.new(
            :name => tag_name, :account_id => act_on.account_id)
        act_on.tags << tag
      end
      
    end
#    def priority(act_on)
#      act_on.priority = act_hash[:value]
#    end
end
