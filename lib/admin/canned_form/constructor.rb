class Admin::CannedForm::Constructor
  include ActionView::Helpers::FormHelper
  include ActionView::Helpers::FormOptionsHelper

  def initialize(args)
    @field = args[:field]
    @disabled = args[:disabled]
    @field_name = @field[:name]
    @object_name = args[:object_name].to_s
    field_label = @field[:label] || ''
    @label = label_tag @object_name + '_' + @field[:name], field_label
    @element_class = "canned-form-#{@field[:name].split('_')[0]}"
  end

  def text_element
    @label + text_field(@object_name, @field_name, :class => @element_class, :disabled => @disabled, :placeholder => @field[:placeholder])
  end

  def dropdown_element
    choices = []
    @field[:choices].each do |choice|
      choice.symbolize_keys!
      choices << choice[:value] unless choice[:_destroy]
    end
    @label + select(@object_name, @field_name, choices, { :include_blank => '...' }, { :disabled => @disabled, :class => @element_class + ' select2' })
  end

  def paragraph_element
    @label + text_area(@object_name, @field_name, :class => @element_class, :placeholder => @field[:placeholder], :rows => 5, :cols => 50)
  end

  def checkbox_element
    element_class = 'btn'
    value1 = I18n.t('plain_yes')
    value2 = I18n.t('plain_no')
    radio_button1 = radio_button_tag(%(#{@object_name}[#{@field_name}]), true, false)
    label1 = content_tag(:label, radio_button1 + value1, :class => element_class)
    radio_button2 = radio_button_tag(%(#{@object_name}[#{@field_name}]), false)
    label2 = content_tag(:label, radio_button2 + value2, :class => element_class)
    checkbox_element = content_tag(:div, label1 + label2, :class => "btn-group #{@element_class}", :role => 'group', :"data-toggle" => 'buttons')
    @label + checkbox_element
  end
end
