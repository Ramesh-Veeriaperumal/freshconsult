class Admin::QuestsController < Admin::AdminController
  include ModelControllerMethods
	include Va::Constants
	include Gamification::Quests::Constants
  
  before_filter { |c| c.requires_feature :gamification }
  before_filter :set_filter_data, :only => [ :create, :update ]
  before_filter :load_config, :only => [:new, :edit]

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
      @badge_class = Gamification::Quests::Badges::BADGES_BY_ID[@quest.badge_id]
    end

    def build_object #Some bug with build during new, so moved here from ModelControllerMethods
      @quest = params[:quest].nil? ? Quest.new : scoper.build(params[:quest])
    end

    def load_config
      @op_types        = ActiveSupport::JSON.encode OPERATOR_TYPES
      @op_list        = ActiveSupport::JSON.encode OPERATOR_LIST
      @available_badges = Gamification::Quests::Badges::BADGES
      
      filter_hash = {
        :ticket   => add_custom_filters(ticket_filters),
        :solution => solution_filters,
        :forum    => forum_filters
      }
      
      @criteria_defs = ActiveSupport::JSON.encode QUEST_BASE_CRITERIA
      @filter_defs   = ActiveSupport::JSON.encode filter_hash
    end
    
    def ticket_filters
      [
        { :name => -1, :value => "--- #{I18n.t('click_to_select_filter')} ---" },
        { :name => "priority", :value => I18n.t('ticket.priority'), :domtype => "dropdown", 
          :choices => Helpdesk::Ticket::PRIORITY_NAMES_BY_KEY.sort, :operatortype => "choicelist" },
        { :name => "ticket_type", :value => t('ticket.type'), :domtype => "dropdown", 
          :choices => current_account.ticket_type_values.collect { |c| [ c.value, c.value ] }, 
          :operatortype => "choicelist" },
        { :name => "source", :value => I18n.t('ticket.source'), :domtype => "dropdown", 
          :choices => Helpdesk::Ticket::SOURCE_NAMES_BY_KEY.sort, :operatortype => "choicelist" },
        { :name => "fcr", :value => I18n.t('quests.fcr'),:choices =>[['true','true']], :domtype => "dropdown" },
        { :name => "satisfaction", :value => I18n.t('quests.satisfaction'), :domtype => "dropdown", 
          :choices => Survey.survey_names(current_account), :operatortype => "choicelist" },
      ]
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
        end
      end

      filter_hash
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
    
    def solution_filters
      [
        { :name => -1, :value => "--- #{I18n.t('click_to_select_filter')} ---" },
        { :name => "folder_id", :value => I18n.t('quests.solution_folder'), :domtype => "optgroup", 
          :choices => Solution::Category.folder_names(current_account), :operatortype => "choicelist" },
         { :name => "thumbs_up", :value => I18n.t('quests.solution_likes'), :domtype => "number", 
          :operatortype => 'greater' }
      ]
    end
    
    def forum_filters
      [
        { :name => -1, :value => "--- #{I18n.t('click_to_select_filter')} ---" },
        { :name => "forum_id", :value => I18n.t('quests.forums'), :domtype => "optgroup", 
          :choices => ForumCategory.forum_names(current_account), :operatortype => "choicelist" }, 
        { :name => "user_votes", :value => I18n.t('quests.customer_votes'), :domtype => "number", 
          :operatortype => 'greater' }
      ]
    end
end