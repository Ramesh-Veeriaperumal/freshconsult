module HelpWidgetTestHelper
  def create_widget(options = {})
    test_widget = FactoryGirl.build(:help_widget,
                                    name: options[:name] || Faker::Name.name,
                                    account_id: @account.id,
                                    product_id: options[:product_id],
                                    settings: options[:settings] || settings_hash(options),
                                    active: 1)
    test_widget.save
    test_widget
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

  def central_publish_help_widget_pattern(widget)
    {
      id: widget.id,
      name: widget.name,
      active: widget.active,
      product_id: widget.product_id,
      account_id: widget.account_id
    }
  end
end
