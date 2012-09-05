class Admin::QuestsController < Admin::AdminController
  include ModelControllerMethods
	
  before_filter { |c| c.requires_feature :scoreboard }
  before_filter :set_filter_data, :only => [ :create, :update ]
  before_filter :load_config, :only => [:new, :edit]

  QUEST_CRITERIA_TYPES = [
    { :criteria_type => ['priority', 'source'] },
    { :criteria_type => ['solutionstatus', 'solutiontype'] },
    { :criteria_type => [] },
    { :criteria_type => ['satisfaction'] }
  ]


  OPERATOR_TYPES = {
    :choicelist  => [ "is","is_not"],
    :checkbox    => [ "selected", "not_selected"],
    :number      => [ "is","is_not"]
  }

  OPERATOR_LIST =  {
    :is  =>  I18n.t('is'),
    :is_not            =>  I18n.t('is_not'),
    :selected          =>  I18n.t('selected'),
    :not_selected      =>  I18n.t('not_selected'),
    :contains          =>  I18n.t('contains')
  }

  QUEST_MODE = [
      [ :create, "Create", 1],
      [ :answer, "Answer", 2]
  ]

  CF_OPERATOR_TYPES = {
    "custom_dropdown" => "choicelist",
    "custom_checkbox" => "checkbox",
    "custom_number"   => "number",
    "nested_field"    => "nestedlist",
  }

  QUEST_MODE_BY_KEY = Hash[*QUEST_MODE.map { |i| [i[2], i[1]] }.flatten]

  QUEST_TIME = [
      [ :anytime,      "Any time",     1 ],
      [ :oneday,       "1 day",        2 ],
      [ :twodays,      "2 days",       3 ],
      [ :oneweek,      "1 week",       4 ],
      [ :twoweeks,     "2 weeks",      5 ],
      [ :onemonth,     "1 month",      6 ],
      [ :oneyear,      "1 year",       7 ],
  ]

  QUEST_TIME_BY_KEY = Hash[*QUEST_TIME.map { |i| [i[2], i[1]] }.flatten] 
  
  CRITERIA_HASH = [
      { :name => "quest_ticket", :disp_name => "Resolve ##questvalue## Tickets within ##questtime##", 
        :input => ["questvalue","questtime"], :questtime => QUEST_TIME_BY_KEY.sort},

      { :name => "quest_solution", :disp_name => "Create ##questvalue## Knowledgebase article within ##questtime##", 
        :input => ["questvalue","questtime"], :questtime => QUEST_TIME_BY_KEY.sort},

      { :name => "quest_forum", :disp_name => "##questmode## ##questvalue## Forum posts within ##questtime##", 
        :input => ["questvalue","questmode","questtime"], :questmode => QUEST_MODE_BY_KEY.sort, :questtime => QUEST_TIME_BY_KEY.sort },

      { :name => "quest_survey", :disp_name => "Get ##questvalue## Survery feedback within ##questtime##", 
        :input => ["questvalue","questtime"], :questtime => QUEST_TIME_BY_KEY.sort}
  ]

  def index
    redirect_back_or_default '/admin/gamification'
  end

  def edit
    edit_data
  end

  def create
    @quest.award_data = ActiveSupport::JSON.decode params[:award_data]
    if @quest.save
      flash[:notice] = t(:'flash.general.create.success', :human_name => human_name)
      redirect_back_or_default '/admin/gamification'
    else
      load_config
      edit_data
      render :action => 'new'
    end  
  end

   def update
    if @quest.update_attributes(params[:quest])
      flash[:notice] = t(:'flash.general.update.success', :human_name => human_name)
      redirect_back_or_default '/admin/gamification'
    else
      load_config
      edit_data
      render :action => 'edit'
    end
  end

  def deactivate
    quest = scoper.find(params[:id])
    quest.active = false
    quest.save
    redirect_back_or_default '/admin/gamification'
  end
  
  def activate
    quest = all_scoper.disabled.find(params[:id])
    quest.active = true
    quest.save
    redirect_back_or_default '/admin/gamification'
  end

  protected

    def scoper
      current_account.quests
    end
    
    def all_scoper
      current_account.all_quests
    end

    def set_filter_data
      @quest.award_data = params[:award_data].blank? ? [] : ActiveSupport::JSON.decode(params[:award_data])
      @quest.filter_data = params[:filter_data].blank? ? [] : ActiveSupport::JSON.decode(params[:filter_data])
      @quest.quest_data = params[:quest_data].blank? ? [] : ActiveSupport::JSON.decode(params[:quest_data])
    end

    def edit_data
      @award_input = ActiveSupport::JSON.encode @quest.award_data
      @filter_input = ActiveSupport::JSON.encode @quest.filter_data
      @quest_input = ActiveSupport::JSON.encode @quest.quest_data
    end

    def build_object #Some bug with build during new, so moved here from ModelControllerMethods
      @quest = params[:quest].nil? ? Quest.new : scoper.build(params[:quest])
    end

    def load_config
      @op_types        = ActiveSupport::JSON.encode OPERATOR_TYPES
      @op_list        = ActiveSupport::JSON.encode OPERATOR_LIST

      @current_account.solution_categories.find(:all)
      
      filter_hash = [
        { :name => -1, :value => "--- #{I18n.t('click_to_select_filter')} ---" },
        { :name => "priority", :value => I18n.t('ticket.priority'), :domtype => "dropdown", 
          :choices => Helpdesk::Ticket::PRIORITY_NAMES_BY_KEY.sort, :operatortype => "choicelist" },
        { :name => "status", :value => I18n.t('ticket.status'), :domtype => "dropdown", 
          :choices => Helpdesk::TicketStatus.status_names(current_account), :operatortype => "choicelist" },
        { :name => "source", :value => I18n.t('ticket.source'), :domtype => "dropdown", 
          :choices => Helpdesk::Ticket::SOURCE_NAMES_BY_KEY.sort, :operatortype => "choicelist" },
        { :name => "solutionstatus", :value => I18n.t('solution.status'), :domtype => "dropdown", 
          :choices => Solution::Article::STATUS_NAMES_BY_KEY.sort, :operatortype => "choicelist" },
        { :name => "solutiontype", :value => I18n.t('solution.type'), :domtype => "dropdown", 
          :choices => Solution::Article::TYPE_NAMES_BY_KEY.sort, :operatortype => "choicelist" },
        { :name => "satisfaction", :value => I18n.t('quests.satisfaction'), :domtype => "dropdown", 
          :choices => Survey.survey_names(current_account), :operatortype => "choicelist" },
        { :name => "forums", :value => I18n.t('quests.forums'), :domtype => "dropdown", 
          :choices => Forum.forum_names(current_account), :operatortype => "choicelist" }, 
        { :name => "datetime", :value => I18n.t('quests.date'), :domtype => "dropdown", 
          :choices => QUEST_TIME_BY_KEY.sort, :operatortype => "choicelist" }
        
      ]
      add_custom_filters filter_hash
      @quest_criteria_types = ActiveSupport::JSON.encode QUEST_CRITERIA_TYPES
      @criteria_defs = ActiveSupport::JSON.encode CRITERIA_HASH
      @filter_defs   = ActiveSupport::JSON.encode filter_hash
    
    end

    def add_custom_filters filter_hash
      current_account.ticket_fields.custom_fields.each do |field|
        if field.field_type == 'custom_dropdown' || field.field_type == 'custom_checkbox' || field.field_type == 'custom_number'
          filter_hash.push({
            :id => field.id,
            :name => field.name,
            :value => field.label,
            :field_type => field.field_type,
            :domtype => (field.field_type == "nested_field") ? "nested_field" : field.flexifield_def_entry.flexifield_coltype,
            :choices =>  (field.field_type == "nested_field") ? field.nested_choices : field.picklist_values.collect { |c| [c.value, c.value ] },
            :action => "set_custom_field",
            :operatortype => CF_OPERATOR_TYPES.fetch(field.field_type, "text"),
            :nested_fields => nested_fields(field)
          })
          QUEST_CRITERIA_TYPES[0][:criteria_type] = QUEST_CRITERIA_TYPES[0][:criteria_type].push(field.name).uniq
        end
      end
    end

    def nested_fields ticket_field
      nestedfields = { :subcategory => "", :items => "" }
      if ticket_field.field_type == "nested_field"
        ticket_field.nested_ticket_fields.each do |field|
          nestedfields[(field.level == 2) ? :subcategory : :items] = { :name => field.field_name, :label => field.label }      
        end
      end
      nestedfields
    end
end