class Social::Gnip::Rule
  include Social::Gnip::Constants
  include Social::Gnip::RuleHelper
  include Social::Gnip::DbUtil
  
  attr_accessor :replay
  
  def initialize(twt_handle, options = {})
    @account = options[:account] || twt_handle.account
    @subscribe = options[:subscribe]
    @twitter_handle = twt_handle
  end
  
  
  def set_stream(stream)
    @stream_name = stream 
    @replay = stream.eql?(STREAM[:replay]) 
    @rule_url = @replay ? GnipConfig::REPLAY_RULES_URL : GnipConfig::PRODUCTION_RULES_URL 
  end
  
  
  def streams
    if @twitter_handle 
      gnip_state = @twitter_handle.gnip_rule_state
      case gnip_state
      when Social::TwitterHandle::GNIP_RULE_STATES_KEYS_BY_TOKEN[:none]
        streams = @subscribe ? [STREAM[:replay], STREAM[:production]] : []
      when Social::TwitterHandle::GNIP_RULE_STATES_KEYS_BY_TOKEN[:production]
        streams = @subscribe ? [STREAM[:replay]] : [STREAM[:production]]
      when Social::TwitterHandle::GNIP_RULE_STATES_KEYS_BY_TOKEN[:replay]
        streams = @subscribe ? [STREAM[:production]] : [STREAM[:replay]]
      when Social::TwitterHandle::GNIP_RULE_STATES_KEYS_BY_TOKEN[:both]
        streams = @subscribe ? [] : [STREAM[:replay],STREAM[:production]]
      else
        streams = []
        NewRelic::Agent.notice_error("Invalid gnip_rule_state for #{@twitter_handle.id}")
      end
    else   #unsubscribe case where twitter handle is destroyed
      streams = [STREAM[:production], STREAM[:replay]]      
    end
    streams
  end
  

  def add
    begin
      new_rule_value = build_rule_value
      mrule = matching_rule(new_rule_value)
      unless mrule.nil?
        update(mrule)
      else
        new_rule_tag = Social::Gnip::RuleTag.build(@twitter_handle.id, @twitter_handle.account_id)
        add_response = add_helper(new_rule_value, new_rule_tag)
        if add_response
          params = {
            :handle => @twitter_handle,
            :action => RULE_ACTION[:add],
            :response => add_response,
            :rule_value => new_rule_value,
            :rule_tag => new_rule_tag
          }
          update_db(params)
          puts "Rule successfully added in #{@stream_name}"
        else
          args = {
            :account_id => @account.id,
            :twitter_handle_id => @twitter_handle.id
          }
          requeue(args)
        end
      end
    rescue => e
      error_params = {
        :description => "Exception in adding rules to gnip in #{@stream_name}",
        :account_id => @twitter_handle.account_id,
        :handle_id => @twitter_handle.id
      }
      NewRelic::Agent.notice_error(e, :custom_params => error_params)
      puts "Exception in adding rules to gnip #{e.backtrace.join("\n")} #{e.to_s}"
    end
  end
  

  def remove(args)
    begin
      rule_value = args[:rule_value]
      rule_tag = args[:rule_tag]
      remove_response = remove_helper(rule_value, rule_tag)
      if remove_response
        handle = @account.twitter_handles.find_by_id(args[:twitter_handle_id])
        params = {
          :handle => handle,
          :action => RULE_ACTION[:delete],
          :response => remove_response
        }
        update_db(params) if handle
        tag = Social::Gnip::RuleTag.build(args[:twitter_handle_id], args[:account_id])
        tag_array = rule_tag.split(DELIMITER[:tags])
        tag_array.delete(tag) 
        puts "Rule successfully removed from #{@stream_name} " 
        #Check tag array and update other twitter handles if they exist    
        unless tag_array.empty?  
          new_rule_tag = tag_array.join(DELIMITER[:tags])
          add_response = add_helper(rule_value,new_rule_tag)
          if add_response
            bulk_update_twitter_handles(new_rule_tag, RULE_ACTION[:update][:success], new_rule_tag) \
                                                                     unless @replay
            puts "Rule successfully added after removing from #{@stream_name}"
          else
            bulk_update_twitter_handles(new_rule_tag, RULE_ACTION[:update][:failure])
          end
        end
      else
        requeue(args)
      end
    rescue => e
      NewRelic::Agent.notice_error(e.to_s, :custom_params => {
                    :description => "Exception in removing rules in #{@stream_name} from Gnip ",
                    :args => args })
      puts "exception in removing rules #{e.to_s} -- #{e.backtrace.join("\n")}"
    end
  end
  

  #Update matching_rule with current twitter handle's tag
  def update(matching_rule)
    args = {
      :account_id => @account.id,
      :twitter_handle_id => @twitter_handle.id
    }
    params = {
      :handle => @twitter_handle,
      :action => RULE_ACTION[:add],
      :rule_value => matching_rule.value,
    }
    twitter_handle_ids = Social::Gnip::RuleTag.handle_ids(matching_rule.tag)
    unless twitter_handle_ids.include?(@twitter_handle.id.to_s)
      remove_response = remove_helper(matching_rule.value, matching_rule.tag)
      #First delete the old rule
      if remove_response  
        new_rule_tag = Social::Gnip::RuleTag.update(matching_rule.tag, @twitter_handle)
        add_response = add_helper(matching_rule.value, new_rule_tag)
        #Add the new rule with updated tag
        if add_response 
          unless @replay
            bulk_update_twitter_handles(matching_rule.tag, RULE_ACTION[:update][:success], new_rule_tag) 
          end
          params = params.merge({
                :response => add_response,
                :rule_tag => new_rule_tag
          })
          update_db(params)
          puts "Rule successfully updated in  #{@stream_name}" 
        else
          bulk_update_twitter_handles(matching_rule.tag, RULE_ACTION[:update][:failure])
          requeue(args)
        end
      else
        requeue(args)
      end
    else
      unless db_sanity
        params = params.merge({
            :rule_tag => matching_rule.tag,
            :response => true
        })
        update_db(params)
      end
    end
  end
  

  #Used for maintenanace. Checks the sanity of the DB data with rules present in Gnip and vice-versa
  def self.mismatch(db_set, rule_url, stream)
    begin
      rules_list = rule_url.list()
      gnip_set = rules_list.inject(Set.new) do |set,rule|
        set << {:rule_value => rule.value, :rule_tag => rule.tag}
        set
      end
      unless ((gnip_set - db_set) + (db_set - gnip_set)).blank?
        error_params = {
          :rules_in_gnip_and_not_in_db => (gnip_set - db_set).inspect,
          :rules_in_db_and_not_in_gnip => (db_set - gnip_set).inspect
        }
        puts "Mismatch of rules in #{stream} :::: #{error_params}"
        NewRelic::Agent.notice_error("Mismatch of rules in #{stream}", :custom_params => error_params)
        SocialErrorsMailer.deliver_mismatch_in_rules(error_params)
      end
    rescue => e
      puts "Exception in checking for mismatch #{e.to_s} #{e.backtrace.join("\n")} "
      NewRelic::Agent.notice_error(e.to_s, :custom_params => {
                                     :description => "Exception in checking for mismatch"
      })
    end
  end

  private 

  def build_rule_value
    @twitter_handle.formatted_handle.strip
  end
  
  
  def matching_rule(rule_value)
    begin
      rules_list = @rule_url.list
      rules_list.each do |rule|
        rule_val = rule.value
        return rule if equality?(rule_val,rule_value)
      end
    rescue => e
      puts "Exception in matching_rule #{e} in #{@stream_name}"
      args = {
        :account_id => @account.id,
        :twitter_handle_id => @twitter_handle.id
      }
      requeue(args)
      NewRelic::Agent.notice_error(e.to_s, :custom_params => {
          :description => "Exception in matching_rule in #{@stream_name} " })
    end
    return nil
  end
  
  def db_sanity(matching_rule)
    equality?(@twitter_handle.rule_value,matching_rule.value) && equality?(@twitter_handle.rule_tag,matching_rule.tag)
  end
  
  def equality?(*args)
    args.first.downcase.strip().eql?(args.second.downcase.strip())
  end
  
end
