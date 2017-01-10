class Admin::SkillsController < Admin::AdminController
  include ModelControllerMethods
  include Va::Constants

  before_filter { |c| c.requires_feature :skill_based_round_robin }
  before_filter :check_max_skills_limit,  :only => [:new, :create]
  before_filter :load_object,             :only => [:edit, :update, :destroy, :users]
  before_filter :escape_html_entities_in_json
  before_filter :load_config,             :only => [:new, :edit]
  before_filter :set_filter_data,         :only => [:create, :update]
  
  include Helpdesk::ReorderUtility

  def index
    @skills = current_account.skills_trimmed_version_from_cache
    respond_to do |format|
      format.html { @skills } #index.html.erb
      format.any(:json) { render request.format.to_sym => @skills.map {|rule| {:id => rule.id, :name => rule.name, :active => rule.active} }}
    end
  end

  def create
    if @skill.save
      flash[:notice] = t(:'flash.general.create.success', :human_name => human_name)
      flash[:highlight] = dom_id(@skill)
      redirect_back_or_default redirect_url
    else
      load_config
      edit_data
      render :action => 'new'
    end
  end

  def edit
    edit_data
  end

  def update
    if @skill.update_attributes(params[:admin_skill])
      respond_to do |format|
        format.html{
          flash[:notice] = t(:'flash.general.update.success', :human_name => human_name)
          flash[:highlight] = dom_id(@skill)
          redirect_back_or_default redirect_url
        }
        format.json{
          render :json => { :status => 200 }
        }
      end
    else
      respond_to do |format|
        format.html{
          load_config
          edit_data
          render :action => 'edit'
        }
        format.json{
          render :json => { :status => 500 } 
        }
      end
    end
  end

  def users
    users = @skill.users.preload(:avatar).trimmed
    user_details = users.map do |user|
      {:id => user.id, :text => user.name, :forSort => user.name.upcase, :profile_img => (user.avatar.nil? ? false : user.avatar.expiring_url(:thumb, 300))}
    end
    render :json => user_details
  end

  protected

    def scoper
      current_account.skills
    end

    def all_scoper
      current_account.skills
    end

    def reorder_scoper
      current_account.skills
    end

    def reorder_redirect_url
      redirect_url
    end

    def human_name
      I18n.t('admin.skills.human_name')
    end

    def redirect_url
      admin_skills_path
    end

    def set_filter_data
      @skill.user_ids    = params[:user_ids].blank? ? [] : ActiveSupport::JSON.decode(params[:user_ids]) if params.key?(:user_ids)
      if params.key?(:filter_data)
        @skill.filter_data = params[:filter_data].blank? ? [] : ActiveSupport::JSON.decode(params[:filter_data]) 
        set_nested_fields_data @skill.filter_data
      end
    end

    def set_nested_fields_data(data)
      data.each do |f|
        f['nested_rules'] = (ActiveSupport::JSON.decode f['nested_rules']).map{ |a| a.symbolize_keys! } if (f['nested_rules'])
      end
    end

    def edit_data
      @filter_input = ActiveSupport::JSON.encode @skill.filter_data
    end

    def build_object
      @skill = params[:admin_skill].nil? ? scoper.new(:match_type => 'all') : scoper.build(params[:admin_skill])
    end

    def check_max_skills_limit
      if current_account.skills.count >= Admin::Skill::MAX_NO_OF_SKILLS_PER_ACCOUNT
        flash[:notice] = I18n.t('activerecord.errors.messages.max_skills_per_account', :max_limit => Admin::Skill::MAX_NO_OF_SKILLS_PER_ACCOUNT)
        redirect_to admin_skills_path
      end
    end

    def load_object
      @skill = all_scoper.find(params[:id])
      @obj   = @skill #Destroy of model-controller-methods needs @obj
    end

    def load_config
      @groups  = current_account.groups.order('name').trimmed.inject([["", I18n.t('ticket.none')]]) do |groups, ag|
                groups << [ag.id, CGI.escapeHTML(ag.name)]
                groups
              end
      @products = current_account.products.trimmed.collect {|p| [p.id, p.name]}
      @skill.filter_data.each &:symbolize_keys!
      
      filter_hash = {}
      add_ticket_fields filter_hash

      add_contact_fields filter_hash
      add_company_fields filter_hash

      @filter_defs  = ActiveSupport::JSON.encode filter_hash

      operator_types = OPERATOR_TYPES.clone
      
      @op_types     = ActiveSupport::JSON.encode operator_types
      @op_list      = ActiveSupport::JSON.encode OPERATOR_LIST
      @op_label     = ActiveSupport::JSON.encode ALTERNATE_LABEL
    end

    def add_ticket_fields filter_hash
      filter_hash['ticket']   = [
        { :name => -1, :value => t('click_to_select_filter') },
        { :name => "priority", :value => t('ticket.priority'), :domtype => "multiple_select", 
          :choices => TicketConstants.priority_list.sort, :operatortype => "choicelist" },
        { :name => "ticket_type", :value => t('ticket.type'), :domtype => "multiple_select", 
          :choices => current_account.ticket_type_values.collect { |c| [ c.value, c.value ] }, 
          :operatortype => "choicelist" },
        { :name => "source", :value => t('ticket.source'), :domtype => "multiple_select", 
          :choices => TicketConstants.source_list.sort, :operatortype => "choicelist" },
        { :name => "product_id", :value => t('admin.products.product_label_msg'), :domtype => "multiple_select", 
          :choices => [['', t('none')]]+@products, :operatortype => "choicelist", :condition => multi_product_account? },
        { :name => "group_id", :value => I18n.t('ticket.group'), :domtype => "multiple_select",
          :operatortype => "object_id", :choices => @groups }
      ]

      filter_hash['ticket'] = filter_hash['ticket'].select{ |filter| filter.fetch(:condition, true) }
      add_custom_filters filter_hash['ticket']
    end

    def add_custom_filters filter_hash
      special_case = [['', t('none')]]
      nested_special_case = [['--', t('any_val.any_value')], ['', t('none')]]
      cf = current_account.ticket_fields.nested_and_dropdown_fields
      unless cf.blank?
        filter_hash.push({ :name => -1,
                           :value => "---------------------"
                           })
        cf.each do |field|
          filter_hash.push({
                             :id => field.id,
                             :name => field.name,
                             :value => field.label,
                             :field_type => field.field_type,
                             :domtype => (field.field_type == "nested_field") ? "nested_field" : 
                                    field.flexifield_def_entry.flexifield_coltype == "dropdown" ? "multiple_select" : field.flexifield_def_entry.flexifield_coltype,
                             :choices =>  (field.field_type == "nested_field") ? (field.nested_choices_with_special_case nested_special_case) : special_case+field.picklist_values.collect { |c| [c.value, c.value ] },
                             :action => "set_custom_field",
                             :operatortype => CF_OPERATOR_TYPES.fetch(field.field_type, "text"),
                             :nested_fields => nested_fields(field)
          })
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


    def add_contact_fields filter_hash
      filter_hash['requester'] = [
        { :name => -1, :value => t('click_to_select_filter') },
        { :name => "language", :value => t('requester_language'), :domtype => "multiple_select", 
          :choices => AVAILABLE_LOCALES, :operatortype => "choicelist",
          :condition => multi_language_account? }
      ]
      add_customer_custom_fields filter_hash['requester'], "contact"
    end

    def add_company_fields filter_hash
      filter_hash['company'] = [
        { :name => -1, :value => t('click_to_select_filter') },
        { :name => "name", :value => t('company_name'), :domtype => "autocomplete_multiple", 
          :data_url => companies_search_autocomplete_index_path, :operatortype => "choicelist" },
        { :name => "domains", :value => t('company_domain'), :domtype => "text", 
          :operatortype => "choicelist" }
      ]
      add_customer_custom_fields filter_hash['company'], "company"
    end

    def add_customer_custom_fields filter_hash, type
      special_case = [['', t('none')]]
      cf = current_account.send("#{type}_form").custom_drop_down_fields
      unless cf.blank? 
        filter_hash.push({ :name => -1,
                          :value => "---------------------" 
                          })
        cf.each do |field|
          filter_hash.push({
            :id => field.id,
            :name => "#{field.name}",
            :value => field.label,
            :field_type => field.field_type,
            :domtype => (field.dom_type == :dropdown_blank) ? "multiple_select" : field.dom_type,
            :choices => special_case+field.custom_field_choices.collect { |c| [c.value, c.value ] },
            :action => "set_custom_field",
            :operatortype => CF_CUSTOMER_TYPES.fetch(field.field_type.to_s, "text"),
            :nested_fields => nested_fields(field)
          })
        end
      end
    end

    def multi_product_account?
      current_account.features?(:multi_product)
    end

    def multi_language_account?
      current_account.features?(:multi_language)
    end

    def escape_html_entities_in_json
      ActiveSupport::JSON::Encoding.escape_html_entities_in_json = true
    end

end
