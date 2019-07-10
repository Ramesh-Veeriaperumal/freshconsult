require Rails.root.join('spec', 'support', 'products_helper.rb')
module HelpWidgetsTestHelper
  include ProductsHelper
  def create_widget(options = {})
    if options[:product_id]
      product_id = options[:product_id]
    else
      test_product = create_product(portal_url: Faker::Internet.url)
      product_id = test_product.id
    end
    test_widget = FactoryGirl.build(:help_widget,
                                    name: options[:name] || Faker::Name.name,
                                    account_id: @account.id,
                                    product_id: product_id,
                                    settings: options[:settings] || settings_hash(options))
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
      contact_form: options[:contact_form] == false ? options[:contact_form] : true,
      predictive_support: options[:predictive_support] == false ? options[:predictive_support] : true
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
      captcha: options[:captcha] || true
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
      button_color: '#12344d'
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
    widget_hash = {
      name: widget.name,
      product_id:  widget.product_id,
      settings: widget.settings,
      created_at: widget.created_at,
      updated_at: widget.updated_at
    }
  end

  def widget_show_pattern(widget)
    {
      id: widget.id,
      product_id: widget.product_id,
      name: widget.name,
      settings: widget.settings.except(:freshmarketer)
    }
  end

  def widget_pattern(widget)
    widget_hash = {
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
end
