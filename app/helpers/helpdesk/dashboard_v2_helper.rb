module Helpdesk::DashboardV2Helper

  def dashboard_widget_list snapshot
    widgets = []
    widget_type = if dashboardv2_available?
      if current_user.privilege?(:admin_tasks)
        (snapshot == 'admin') ? Dashboard::ADMIN_DASHBOARD : Dashboard::STANDARD_DASHBOARD
      elsif current_user.privilege?(:view_reports)
        (snapshot == 'supervisor') ? Dashboard::SUPERVISOR_DASHBOARD : Dashboard::STANDARD_DASHBOARD
      else
        (snapshot == 'agent') ? Dashboard::AGENT_DASHBOARD : Dashboard::STANDARD_DASHBOARD
      end
    else
      Dashboard::STANDARD_DASHBOARD
    end

    widget_type.each do |widget|
       widgets << widget if widget_privilege[widget.first.to_sym]
    end
    
    widgets
  end

  def widget_privilege
    @widget_privilege_list ||= {
      :tickets        =>  true,
      :activities     =>  true,
      :todo           =>  true,
      :csat           =>  current_account.any_survey_feature_enabled_and_active?,
      :gamification   =>  gamification_feature?(current_account),
      :freshfone      =>  current_account.freshfone_active?,
      :chat           =>  chat_activated? && current_account.chat_setting.active,
      :moderation     =>  current_account.features?(:forums) && privilege?(:delete_topic),
      :agent_status   =>  (round_robin? || current_account.freshfone_active? || (chat_activated? && current_account.chat_setting.active)),
      :trend_count    =>  true
    }
  end


  def dashboardv2_available?  
    dashboardv2_plans = [ SubscriptionPlan::SUBSCRIPTION_PLANS[:garden], SubscriptionPlan::SUBSCRIPTION_PLANS[:estate],
                        SubscriptionPlan::SUBSCRIPTION_PLANS[:forest], SubscriptionPlan::SUBSCRIPTION_PLANS[:garden_classic],
                        SubscriptionPlan::SUBSCRIPTION_PLANS[:estate_classic]]
    dashboardv2_plans.include?(current_account.subscription.subscription_plan.name) rescue false
  end

end