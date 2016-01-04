class Admin::QuestsController < Admin::AdminController
  include ModelControllerMethods
  include SurveyRuleHelperMethods
	include Va::Constants
	include Gamification::Quests::Constants
	include Gamification::Quests::Badges
  
  before_filter { |c| c.requires_feature :gamification }
  before_filter :set_filter_data, :only => [ :create, :update ]
  before_filter :load_config, :only => [:new, :edit]
  before_filter :require_survey_rule, :only => [:edit]

  def index
    redirect_back_or_default '/admin/gamification#quests'
  end

  def edit
    edit_data
  end

  def create    
    if @quest.save
      flash[:notice] = t(:'flash.general.create.success', :human_name => human_name)
      redirect_back_or_default '/admin/gamification#quests'
    else
      load_config
      edit_data
      render :action => 'new'
    end  
  end

   def update
    if @quest.update_attributes(params[:quest])
      flash[:notice] = t(:'flash.general.update.success', :human_name => human_name)
      redirect_back_or_default '/admin/gamification#quests'
    else
      load_config
      edit_data
      render :action => 'edit'
    end
  end

  def toggle
    @quest = all_scoper.find(params[:id])
    @quest.update_attribute(:active, !@quest.active)
  end

  protected

    def scoper
      current_account.all_quests
    end
    
    def all_scoper
      current_account.all_quests
    end

    def set_filter_data
      @quest.filter_data = params[:filter_data].blank? ? [] : ActiveSupport::JSON.decode(params[:filter_data])
      @quest.quest_data = params[:quest_data].blank? ? [] : ActiveSupport::JSON.decode(params[:quest_data])
    end

    def edit_data
      @filter_input = ActiveSupport::JSON.encode @quest.actual_filter_data
      @quest_input = ActiveSupport::JSON.encode @quest.quest_data
      @badge_class = BADGES_BY_ID[@quest.badge_id]
    end

    def build_object #Some bug with build during new, so moved here from ModelControllerMethods
      @quest = params[:quest].nil? ? Quest.new : scoper.build(params[:quest])
    end

    def load_config
      operator_types = OPERATOR_TYPES.clone
      
      operator_types[:choicelist] = ["is", "is_not"]
      operator_types[:object_id] = ["is", "is_not"]

      @op_types         = ActiveSupport::JSON.encode operator_types
      @op_list          = ActiveSupport::JSON.encode OPERATOR_LIST
      @available_badges = available_badges
      
      filter_hash = {
        :ticket   => add_custom_filters(ticket_filters),
        :solution => solution_filters,
        :forum    => forum_filters
      }
      
      @criteria_defs = ActiveSupport::JSON.encode QUEST_BASE_CRITERIA
      @filter_defs   = ActiveSupport::JSON.encode filter_hash
    end
    
    def available_badges #Nasty implementation, need to refactor - Shan
      used_up_badges = current_account.all_quests.collect { |q| q.badge_id }
      BADGES.select { |b| !used_up_badges.include? b[:id] }
    end
    
    def ticket_filters
      ticket_filter = [
        { :name => -1, :value => "#{I18n.t('click_to_select_filter')}" },
        { :name => "priority", :value => I18n.t('ticket.priority'), :domtype => "dropdown", 
          :choices => TicketConstants.priority_list.sort, :operatortype => "choicelist" },
        { :name => "ticket_type", :value => t('ticket.type'), :domtype => "dropdown", 
          :choices => current_account.ticket_type_values.collect { |c| [ c.value, c.value ] }, 
          :operatortype => "choicelist" },
        { :name => "source", :value => I18n.t('ticket.source'), :domtype => "dropdown", 
          :choices => TicketConstants.source_list.sort, :operatortype => "choicelist" },
        { :name => "inbound_count", :value => I18n.t('quests.fcr'), :domtype => "blank_boolen" }
      ]
      if current_account.custom_survey_enabled
        ticket_filter.push(
              { :name => "st_survey_rating", :value => I18n.t('quests.satisfaction'), :domtype => "dropdown", 
                :choices => current_account.custom_surveys.active.first.choice_names.collect { |c| 
                [c[0],CGI.escapeHTML(c[1])]}, :operatortype => "choicelist" 
              }) unless current_account.custom_surveys.active.blank?
      else
        ticket_filter.push(
          { :name => "st_survey_rating", :value => I18n.t('quests.satisfaction'), :domtype => "dropdown", 
            :choices => Survey.survey_names(current_account).collect { |c| 
            [c[0],CGI.escapeHTML(c[1])]}, :operatortype => "choicelist" 
          })
      end
      ticket_filter
    end

    def add_custom_filters filter_hash
      current_account.ticket_fields.custom_fields.each do |field|
        if ['custom_dropdown', 'custom_checkbox', 'custom_number', 'custom_decimal'].include?(field.field_type)
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
        end
      end

      filter_hash
    end

    def nested_fields ticket_field # possible dead code
      nestedfields = { :subcategory => "", :items => "" }
      if ticket_field.field_type == "nested_field"
        ticket_field.nested_ticket_fields.each do |field|
          nestedfields[(field.level == 2) ? :subcategory : :items] = { :name => field.field_name, :label => field.label }      
        end
      end
      nestedfields
    end
    
    def solution_filters
      [
        { :name => -1, :value => "#{I18n.t('click_to_select_filter')}" },
        { :name => "folder_id", :value => I18n.t('quests.solution_folder'), :domtype => "optgroup", 
          :choices => Solution::Category.folder_names(current_account).collect{ |category|  
            [CGI.escapeHTML(category[0]),category[1].collect{ |folder|
               [folder[0],CGI.escapeHTML(folder[1])]
              }]
            }, :operatortype => "choicelist" },
        { :name => "thumbs_up", :value => I18n.t('quests.solution_likes'), :domtype => "number", 
          :operatortype => 'greater' }
      ]
    end
    
    def forum_filters
      [
        { :name => -1, :value => "#{I18n.t('click_to_select_filter')}" },
        { :name => "forum_id", :value => I18n.t('quests.forums'), :domtype => "optgroup", 
          :choices => ForumCategory.forum_names(current_account).collect{ |category|  
            [CGI.escapeHTML(category[0]),category[1].collect{ |forum|
               [forum[0],CGI.escapeHTML(forum[1])]
              }]
            }, :operatortype => "choicelist" }, 
        { :name => "user_votes", :value => I18n.t('quests.customer_votes'), :domtype => "number", 
          :operatortype => 'greater' }
      ]
    end

    private
    
    def survey_data
      {
        :rules => JSON.parse(ActiveSupport::JSON.encode @quest.actual_filter_data),
        :name => 'st_survey_rating',
        :survey_modified_msg => I18n.t('admin.survey_modified'),
        :survey_disabled_msg => I18n.t('quests.survey_disabled_event')
      }
    end
end