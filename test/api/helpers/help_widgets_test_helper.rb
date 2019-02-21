require "#{Rails.root}/spec/support/products_helper.rb"
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

    test_widget.save()
    test_widget
  end

  def settings_hash(options = {})
    {
      message: "Welcome to dovetails support",
      button_text: "Help",
      components: components_hash(options),
      contact_form: contact_settings_hash(options),
      appearance: appearance_hash
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
      theme_color: "#008969",
      button_color: "#12344d"
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
      settings: widget.settings
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
end

