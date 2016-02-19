module Integrations
  class ActionsUtil

    def slack_v2 installed_app, condition
      configs = installed_app["configs"][:inputs]
      choices = slack_v2_choices(configs)
      choices.push([ :"dm_agent", "TicketAgent (#{I18n.t('integrations.slack_v2.action_options.dm')})"]) if configs["allow_dm"].present?
      { :name => "Integrations::RuleActionHandler", :value => "#{I18n.t('integrations.slack_v2.message.push_to_slack')}",
        :choices => choices, :domtype => 'slack',
        :condition => condition[:dispatcher] || condition[:observer] }
    end

    private
      def slack_v2_choices configs
        iterate_types = ["public", "private"]
        labels = {"public" => "#{I18n.t('integrations.slack_v2.action_options.public')}", "private" => "#{I18n.t('integrations.slack_v2.action_options.private')}"}
        choices = []
        iterate_types.each do |type|
          type_label = labels[type]
          if configs["#{type}_channels"].present? && configs["#{type}_labels"].present?
            channel_id_list = configs["#{type}_channels"]
            channel_name_list = configs["#{type}_labels"].split(",")
            channel_id_list.zip(channel_name_list).each do |channel_id, channel_name|
              choices.push(["#{channel_id}", "#{channel_name} (#{type_label})"])
            end
          end
        end
        choices
      end

  end
end