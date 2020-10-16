module HelpdeskReports::Helper::QnaInsightsReports

  include HelpdeskReports::Constants::QnaInsights

  RECENT_QUESTIONS_VERSION = 1
  INSIGHTS_CONFIG_VERISON = 1
  INSIGHTS_CONFIG_G1 = :group1
  INSIGHTS_CONFIG_G2 = :group2
  INSIGHTS_CONFIG_G3 = :group3

  def transform_qna_insight_request
    if params[:report_type]==REPORT_TYPE[:qna]
      params[:_json] = [HelpdeskReports::ParamConstructor::QnaInsightParams.new(params).build_params]
    else
      request_arr = params[:insights].inject([]) { | arr, i_param |  arr << HelpdeskReports::ParamConstructor::QnaInsightParams.new(i_param).build_params }
      params[:_json] = request_arr.flatten
    end
  end

  def get_insights_widget_config (widget_id=nil)
    final_config = {}
    if widget_id.nil?
      config =  current_user.qna_insight ?  current_user.qna_insight.get_insights_config(widget_id) : {}
      final_config = get_default_insight_configuration(widget_id).merge(config.symbolize_keys)
    else
      final_config = (current_user.qna_insight && current_user.qna_insight.get_insights_config(widget_id)) || get_default_insight_configuration(widget_id)
    end
    scope = Agent::PERMISSION_TOKENS_BY_KEY[User.current.agent.ticket_permission]
    final_config.delete(:d10) if Account.current.euc_hide_agent_metrics_enabled? || scope == :assigned_tickets || Account.current.groups_from_cache.count < 1
    final_config.delete(:d11) if ((User.current.agent.agent_groups.count < 2 && ( scope == :group_tickets || scope == :assigned_tickets )) || Account.current.groups_from_cache.count < 2) 
    final_config
  end

  def save_recent_question (question)
    if current_user.qna_insight.nil?
      create_qna_model(recent_question: question)
    else
      current_user.qna_insight.update_recent_question(question)
    end
  end

  def save_insights_config_model
    config = params[:config]
    if current_user.qna_insight.nil?
      create_qna_model(widget_config: config)
    else
      current_user.qna_insight.update_insights_config(config)
    end
  end

  def create_qna_model ( recent_question: nil, widget_config: nil)
    qna_record = current_user.build_qna_insight(
      recent_questions: get_recent_questions_hash(recent_question),
      insights_config_data: get_insights_config_hash(widget_config))
    qna_record.account_id = Account.current.id

    qna_record.save
  end


  private
    def get_recent_questions_hash(recent_question)
     recent_questions_hash =  { version: RECENT_QUESTIONS_VERSION }
     questions = []
     questions << recent_question if recent_question
     recent_questions_hash[:questions] = questions
     recent_questions_hash
    end

    def get_insights_config_hash(widget_config)
     insights_config_hash =  { version: INSIGHTS_CONFIG_VERISON }
     config_hash = {}
     config_hash.merge!(widget_config) if widget_config
     insights_config_hash[:config] = config_hash
     insights_config_hash
    end


    def get_default_insight_configuration(widget_id =nil)
      widget_id ? get_insights_config[widget_id] : get_insights_config
    end

    def get_insights_config_group
      agent_count = Account.current.agents.count
      agent_count > 50 ? INSIGHTS_CONFIG_G3 : agent_count > 9 ? INSIGHTS_CONFIG_G2 : INSIGHTS_CONFIG_G1
    end

     #identify the default config using plan / agent count / widget type
     # and get all default metric config for widgets
    def get_insights_config
      default_config = INSIGHTS_WIDGETS_CONFIG_DEFAULT.deep_dup
      default_threshold_values = get_default_threshold_config
      default_config.each do |key, value|
        value[:threshold] = default_threshold_values[value[:metric]]
      end
      default_config[:d11][:threshold] = default_threshold_values[GROUP_COMPARE_METRIC]
      default_config
    end

    def get_default_threshold_config
      report_plan = ReportsAppConfig::INSIGHTS_DEFAULTS[:insights_threshold_values][Account.current.subscription.subscription_plan.display_name.downcase.to_sym]
      report_plan.present? ? report_plan[get_insights_config_group] : {}
    end

end
