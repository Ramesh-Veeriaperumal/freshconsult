require Rails.root.join('spec', 'support', 'products_helper.rb')
module HelpWidgetsTestHelper
  include ProductsHelper

  EXP_CONSTANTS = {
    none: 1,
    lesser: 2,
    greater: 3
  }.freeze

  def create_widget(options = {})
    if options[:product_id]
      product_id = options[:product_id]
    else
      test_product = create_product(portal_url: Faker::Internet.url, language: options[:language])
      product_id = test_product.id
    end
    test_widget = FactoryGirl.build(:help_widget,
                                    name: options[:name] || Faker::Name.name,
                                    account_id: @account.id,
                                    product_id: product_id,
                                    settings: options[:settings] || settings_hash(options),
                                    active: 1)
    test_widget.save
    test_widget
  end

  def build_solution_categories(help_widget)
    portal = Account.current.portals.find_by_product_id(help_widget.product_id)
    category = create_category(portal_id: portal.id)
    help_widget.help_widget_solution_categories.build(solution_category_meta_id: category.id)
    help_widget.save
    category
  end

  def create_widget_suggested_article_rules(params)
    @widget.help_widget_suggested_article_rules.build(params)
    @widget.save!
    @widget.help_widget_suggested_article_rules
  end

  def set_user_login_headers(name: 'Sagara', email: 'sagara@desert.com', exp: (Time.now.utc + 2.hours), additional_payload: {}, additional_operations: { remove_key: nil })
    secret_key = SecureRandom.hex
    @account.stubs(:help_widget_secret).returns(secret_key)
    remove_key = additional_operations[:remove_key]
    exp = exp.to_i if exp.instance_of?(Time)
    payload = { name: name, email: email, exp: exp }.merge!(additional_payload).reject { |key| key == remove_key }
    @request.env['HTTP_X_WIDGET_AUTH'] = JWT.encode(payload, secret_key)
    exp
  end

  def unset_login_support
    @account.unstub(:help_widget_secret)
  end

  def settings_hash(options = {})
    {
      message: 'Welcome to dovetails support',
      button_text: 'Help',
      components: components_hash(options),
      contact_form: contact_settings_hash(options),
      appearance: appearance_hash,
      predictive_support: predictive_support_hash,
      widget_flow: 2
    }
  end

  def components_hash(options = {})
    {
      contact_form: options.key?(:contact_form) ? options[:contact_form] : true,
      solution_articles: options.key?(:solution_articles) ? options[:solution_articles] : false
    }
  end

  def contact_settings_hash(options = {})
    {
      form_type: options[:form_type] || 1,
      form_title: 'Send us a  message',
      form_button_text: 'Send message',
      form_submit_message: 'Thank you for your feedback',
      screenshot: true,
      attach_file: options[:attach_file] || true,
      captcha: options[:captcha] || true,
      require_login: options[:require_login] || false
    }
  end

  def appearance_hash
    {
      position: 1,
      offset_from_bottom: 30,
      offset_from_left: 30,
      color_schema: 1,
      pattern: 1,
      gradient: 1,
      theme_color: '#00a886',
      button_color: '#12344d',
      theme_text_color: '#ffffff',
      button_text_color: '#ffffff'
    }
  end

  def predictive_support_hash
    {
      welcome_message: 'Hello , I am ADA !',
      message: 'Hai , how may I help you ?',
      success_message: 'Awesome, Happy that your problem has been addressed'
    }
  end

  def widget_hash(widget)
    {
      name: widget.name,
      product_id:  widget.product_id,
      settings: widget.settings,
      created_at: widget.created_at,
      updated_at: widget.updated_at
    }
  end

  def widget_bootstrap_pattern(user, expire_at, email = nil)
    {
      user: {
        id: user.id,
        name: user.name,
        email: email || user.email,
        phone: user.phone,
        mobile: user.mobile,
        external_id: user.external_id,
        language: user.language
      },
      meta: {
        expire_at: expire_at
      }
    }
  end

  def widget_show_pattern(widget)
    ret_hash = {
      id: widget.id,
      product_id: widget.product_id,
      name: widget.name,
      settings: widget.settings.except(:freshmarketer)
    }
    ret_hash[:solution_category_ids] = widget.help_widget_solution_categories.pluck(:solution_category_meta_id)
    ret_hash
  end

  def widget_pattern(widget)
    {
      id: widget.id,
      product_id: widget.product_id,
      name: widget.name,
      settings: widget.settings,
      created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      updated_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$}
    }
  end

  def widget_list_pattern(widget)
    {
      id: widget.id,
      product_id: widget.product_id,
      name: widget.name
    }
  end

  def suggested_article_rules_index_pattern(widget)
    suggested_article_rules = widget.help_widget_suggested_article_rules
    rule_list = suggested_article_rules.each_with_object([]) do |rule, list|
      list << rule_pattern(rule)
      list
    end
    rule_list
  end

  def rule_pattern(rule)
    {
      id: rule.id,
      conditions: rule.conditions,
      rule_operator: rule.rule_operator,
      filter: rule.filter,
      position: rule.position
    }
  end

  def validation_error_pattern(value)
    {
      description: 'Validation failed',
      errors: [value]
    }
  end

  def toggle_required_attribute(fields)
    fields.each do |field|
      field.required_in_portal = !field.required_in_portal
      field.save
    end
  end

  def toggle_editable_in_portal(fields)
    fields.each do |field|
      field.editable_in_portal = !field.editable_in_portal
      field.save
    end
  end

  def freshmarketer_hash
    {
      acc_id: '4151515152535E435F41585143594C5A5F5F5B',
      auth_token: 'f05bjpn7lh1vi7gm2ioahpbe8jkmalhl06hjf3jj',
      cdn_script: "<script src='//s3-us-west-2.amazonaws.com/zargetlab-js-bucket/200002700/5004.js'></script>",
      app_url: 'https://harlin-mani.fmstack2.com/ab/#/org/200002700/project/5004/experiment/5006/session/sessions',
      integrate_url: 'https://harlin-mani.fmstack2.com/ab/#/org/200002700/project/5004/settings/integration'
    }
  end

  def link_freshmarketer_account
    settings = Account.current.account_additional_settings
    settings.additional_settings = { freshmarketer: freshmarketer_hash }
    settings.save
  end

  def unlink_freshmarketer_account
    freshmarketer_client.unlink_account
  end

  def freshmarketer_client
    @freshmarketer_client ||= ::Freshmarketer::Client.new
  end

  def widget_freshmarketer_hash
    {
      org_id: 200_002_700,
      project_id: 5_004,
      cdn_script: "<script src='//s3-us-west-2.amazonaws.com/zargetlab-js-bucket/200002700/5004.js'></script>"
    }
  end

  def predictive_experiment_hash(widget_id, exp_id = '4151515152505F435F415C51405F594C5C5A5F5F')
    {
      exp_id: exp_id,
      widget_ids: [widget_id]
    }
  end

  def fm_widget_settings(domain, widget_id, exp_id = '4151515152505F435F415C51405F594C5C5A5F5F')
    {
      domain => predictive_experiment_hash(widget_id, exp_id)
    }
  end

  def suggested_article_rule(params = {})
    {
      conditions: [
        {
          evaluate_on: params[:evaluate_on] || HelpWidgetSuggestedArticleRule::EVALUATE_ON[:page],
          name: params[:condition_name] || HelpWidgetSuggestedArticleRule::NAME[:url],
          operator: params[:condition_operator] || HelpWidgetSuggestedArticleRule::OPERATOR[:contains],
          value: params[:condition_value] || 'test'
        }
      ],
      rule_operator: params[:rule_operator] || HelpWidgetSuggestedArticleRule::RULE_OPERATOR[:OR],
      filter: {
        type: params[:filter_type] || HelpWidgetSuggestedArticleRule::FILTER_TYPE[:article],
        order_by: params[:order_by] || HelpWidgetSuggestedArticleRule::ORDER_BY[:hits],
        value: params[:filter_value] || suggested_article_ids
      }
    }
  end

  def suggested_article_ids
    Account.current.solution_article_meta
           .for_help_widget(@widget, User.current)
           .published.limit(5)
           .pluck(:id)
  end
end
