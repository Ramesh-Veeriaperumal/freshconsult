module Social::Util

  include Gnip::Constants

  def select_shard_and_account(account_id)
    begin
      Sharding.select_shard_of(account_id) do
        account = Account.find_by_id(account_id)
        account.make_current if account
      end
      account = Account.current
      yield(account)
    rescue ActiveRecord::RecordNotFound => e
      puts "Could not find account with id #{account_id}"
      NewRelic::Agent.notice_error(e, :custom_params => {:account_id => account_id,
          :description => "Could not find valid account id in DbUtil"})
    end
  end

  def requeue_gnip_rule(resque_class, env, response)
    rule_value = response[:rule_value]
    rule_tag = response[:rule_tag]

    tag_array = rule_tag.split(DELIMITER[:tags])
    tag_array.each do |gnip_tag|
      tag = Gnip::RuleTag.new(gnip_tag)
      args = {
        :account_id => tag.account_id,
        :env => env.to_a,
        :rule => {
          :value => rule_value,
          :tag => gnip_tag
        },
        :action => RULE_ACTION[:add]
      }
      Resque.enqueue_at(5.minutes.from_now, resque_class, args)
    end
  end

  def notify_social_dev(subject, message)
    message.merge!(:environment => Rails.env)
    topic = SNS["social_notification_topic"]
    DevNotification.publish(topic, subject, message.to_json)
  end

end
