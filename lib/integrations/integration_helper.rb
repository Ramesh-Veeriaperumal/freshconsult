module Integrations::IntegrationHelper
  
  def construct_rules(data, default_value)
    unless data.empty?
      output = ""
      output << %(<div class='make_drop rules_wrapper' id='construct_rules' rel='construct_rules' data-default-value='#{default_value.html_safe}'>)

      data.each do |value|
        
        if ( value[:type] == 'dropdown' )
          channel = value[:options]
          output << select_tag(value[:name], options_for_select(channel.collect{ |c| [c["name"],c["id"]]}), { :class => "drop_first " , :rel => "dropdown", "data-refer-key" => value[:refer_key]})
        elsif (value[:type] == 'multi_select')

          output << select_tag(value[:name], options_for_select(value[:options]), { :class => "drop_second" , :rel => "multi_select", "data-refer-key" => value[:refer_key]})
        elsif (value[:type] == 'input_text')

          output << %(<input type="text" name="#{value[:name]}" class="input_text" rel="input_text" data-refer-key="#{value[:refer_key]}">)
        end

      end

      output << %(</div>)
      output.html_safe
    end
  end

  def exists_in_installed_apps? application, installed_apps_list
    result = false
    installed_apps_list.each do |inst_app|
      result = true if application.id == inst_app.application_id
    end
    result
  end

  def append_integration_actions action_hash
    integration_list = ["slack_v2"]
    integration_actions = fetch_integration_actions(integration_list)
    if integration_actions.present?
      action_hash.push(integration_actions)
      action_hash.push({ :name => -1, :value => "-----------------------" })
    end
    action_hash.flatten!
  end

  def fetch_integration_actions integration_list
    integration_actions = []
    installed_apps = current_account.installed_applications.where("applications.name IN (?)", integration_list ).joins(:application)
    obj = Integrations::ActionsUtil.new
    installed_apps.each do |installed_app|
      app_name = installed_app.application.name
      begin
        if obj.respond_to?(app_name)
          condition = { :dispatcher => va_rules_controller?, :observer => observer_rules_controller? }
          option = obj.send(app_name, installed_app, condition)
          integration_actions.push(option)
        end
      rescue => err
        Rails.logger.debug "Error while getting Integration actions : #{err}"
        NewRelic::Agent.notice_error(err)
      end
    end
    integration_actions
  end
end