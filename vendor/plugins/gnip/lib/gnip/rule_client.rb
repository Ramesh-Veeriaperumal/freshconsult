class Gnip::RuleClient

  include Gnip::RuleHelper
  include Gnip::Constants

  attr_accessor :replay

  #This gnip client can be used to add/delete rules from a powertrack stream

  # For adding/deleting a rule, we need source, rule_tag, rule_value

  # rule is a hash containing the "rule value" & "rule tag"
  # powertrack_env is either "production" or "replay"
  # source = twitter/wordpress/disqus/tumblr
  def initialize(source, powertrack_env, rule, options={})
    @source = source
    @environment = powertrack_env
    @rule = rule
    @url = GnipConfig::RULE_CLIENTS[source][powertrack_env.to_sym]
    @replay = powertrack_env.eql?(STREAM[:replay])
    @notification_topic = SNS["social_notification_topic"]
  end

  # Returns updated params if the operation is a success, nil otherwise
  def add
    sandbox do
      rule_value = @rule[:value]
      rule_tag = @rule[:tag]
      response = construct_response(RULE_ACTION[:add], rule_value, rule_tag, false)

      mrule = matching_rule(rule_value)
      unless mrule.nil?
        response = update(mrule)
      else
        add_response = add_helper(rule_value, rule_tag)
        response[RULE_ACTION[:add]][:response] = add_response
      end
      return response
    end
  end

  # "tag" is the specific tag that needs to be deleted from the rule
  # Returns updated params if the operation is a success, nil otherwise
  def delete
    sandbox do
      rule_value = @rule[:value]
      response = construct_response(RULE_ACTION[:delete], rule_value, "", false)
      mrule = matching_rule(rule_value)
      if !mrule.nil? &&  mrule.tag.split(DELIMITER[:tags]).include?(@rule[:tag]) 
        rule_tag = mrule.tag
        delete_response = delete_helper(rule_value, rule_tag)
        response = construct_response(RULE_ACTION[:delete], rule_value, rule_tag, delete_response)

        if delete_response
          tag = @rule[:tag]
          tag_array = rule_tag.split(DELIMITER[:tags])
          tag_array.delete(tag)

          #Check tag array and update other twitter handles if they exist
          unless tag_array.empty?
            new_rule_tag = tag_array.join(DELIMITER[:tags])
            add_response = add_helper(rule_value, new_rule_tag)
            response = construct_response(RULE_ACTION[:add], rule_value, new_rule_tag, add_response, response)
          end
        end
      else
        params = {
          :environment => Rails.env,
          :rule => @rule,          
          :replay => @replay
        }
        DevNotification.publish(@notification_topic, "Deleting a rule not in gnip" , params.to_json)
        response = construct_response(RULE_ACTION[:delete], @rule[:value], @rule[:tag], true)
      end
      return response
    end
  end

  def self.mismatch(db_set, rule_url, stream)
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
      error_params.merge!(:environment => Rails.env, :gnip_env => stream)
      DevNotification.publish(SNS["social_notification_topic"], "Mismatch of rules in #{stream}", error_params.to_json)
    else
      DevNotification.publish(SNS["social_notification_topic"], "No mismatch of rules in #{stream}", {:environment => Rails.env}.to_json)
    end
  end

  private

    #Update matching_rule with a new tag
    def update(matching_rule)
      unless matching_rule.tag.split(DELIMITER[:tags]).include?(@rule[:tag])
        #First delete the old rule
        delete_response = delete_helper(matching_rule.value, matching_rule.tag)
        response = construct_response(RULE_ACTION[:delete], matching_rule.value, matching_rule.tag, delete_response)

        if delete_response
          new_rule_tag = "#{matching_rule.tag}#{DELIMITER[:tags]}#{@rule[:tag]}"
          #Add the new rule with updated tag
          add_response = add_helper(matching_rule.value, new_rule_tag)
          response = construct_response(RULE_ACTION[:add], matching_rule.value, new_rule_tag, add_response, response)
        end
      else
        params = {
          :environment => Rails.env,
          :rule => @rule,
          :matching_rule => {:tag => matching_rule.tag, :value => matching_rule.value},          
          :replay => @replay 
        }
        DevNotification.publish(@notification_topic, "Updating the rule already present in Gnip" , params.to_json)
        response = construct_response(RULE_ACTION[:add], matching_rule.value, matching_rule.tag, true)
      end
      return response
    end

    def matching_rule(value)
      sandbox do
        list = @url.list
        list.each do |rule|
          rule_val = rule.value
          return rule if equality?(rule_val, value)
        end
        return nil
      end
    end

    def equality?(*args)
      args.first.downcase.strip().eql?(args.second.downcase.strip())
    end

    def construct_response(action, value, tag, response, params={})
      params.merge!({
        action => {
          :response => response,
          :rule_value => value,
          :rule_tag => tag
        }
      })
    end

    def sandbox
      begin
        yield
      rescue => e
        puts "Exception in Rule Client #{e.inspect} #{e.backtrace.join("\n")}"
        error_params = {
          :environment => Rails.env,
          :description => "Exception in RuleClient in #{@source} - #{@environment} stream ",
          :rule => @rule.inspect,
          :exception => e.inspect,
          :exception_backtrace => e.backtrace.join("\n")
        }
        DevNotification.publish(@notification_topic, "Exception in rule client", error_params.to_json)
      end
    end

end
