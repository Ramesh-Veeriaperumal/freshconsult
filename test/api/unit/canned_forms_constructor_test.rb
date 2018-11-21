require_relative '../unit_test_helper'
require_relative '../helpers/canned_forms_test_helper'

# Test canned form consturctor class in lib/admin/canned_form/constructor.rb
class CannedFormsConstructorTest < ActionView::TestCase
  include CannedFormsTestHelper

  OBJECT_NAME = :canned_forms
  LABEL_ELEMENT = "<label for=\"canned_forms_%{field_name}\">%{field_label}</label>"
  PLACEHOLDER = " placeholder=\"%{field_placeholder}\""
  TEXT_ELEMENT = "<input class=\"canned-form-%{field_type}\" id=\"canned_forms_%{field_name}\" name=\"canned_forms[%{field_name}]\"%{placeholder} size=\"30\" type=\"text\" />"
  CHECKBOX_ELEMENT = "<div class=\"btn-group canned-form-%{field_type}\" data-toggle=\"buttons\" role=\"group\"><label class=\"btn\"><input id=\"canned_forms_%{field_name}_true\" name=\"canned_forms[%{field_name}]\" type=\"radio\" value=\"true\" />Yes</label><label class=\"btn\"><input id=\"canned_forms_%{field_name}_false\" name=\"canned_forms[%{field_name}]\" type=\"radio\" value=\"false\" />No</label></div>"
  PARAGRAPH_ELEMENT = "<textarea class=\"canned-form-%{field_type}\" cols=\"50\" id=\"canned_forms_%{field_name}\" name=\"canned_forms[%{field_name}]\"%{placeholder} rows=\"5\">\n</textarea>"
  DROPDOWN_ELEMENT = "<select class=\"canned-form-%{field_type} select2\" id=\"canned_forms_%{field_name}\" name=\"canned_forms[%{field_name}]\"><option value=\"\">...</option>%{choices}</select>"
  CHOICE = "\n<option value=\"%{choice}\">%{choice}</option>"

  def test_text_field_render_without_label
    field_type, params, expected = load_text_field_object(:label)
    result = Admin::CannedForm::Constructor.new(params).safe_send("#{field_type}_element")
    assert_equal expected, result
  end

  def test_text_field_render_without_placeholder
    field_type, params, expected = load_text_field_object(:placeholder)
    result = Admin::CannedForm::Constructor.new(params).safe_send("#{field_type}_element")
    assert_equal expected, result
  end

  def test_text_field_render
    field_type, params, expected = load_text_field_object
    result = Admin::CannedForm::Constructor.new(params).safe_send("#{field_type}_element")
    assert_equal expected, result
  end

  def test_checkbox_field_render_without_label
    field_type, params, expected = load_checkbox_object(:label)
    result = Admin::CannedForm::Constructor.new(params).safe_send("#{field_type}_element")
    assert_equal expected, result
  end

  def test_checkbox_field_render
    field_type, params, expected = load_checkbox_object
    result = Admin::CannedForm::Constructor.new(params).safe_send("#{field_type}_element")
    assert_equal expected, result
  end

  def test_paragraph_field_render_without_label
    field_type, params, expected = load_paragraph_object(:label)
    result = Admin::CannedForm::Constructor.new(params).safe_send("#{field_type}_element")
    assert_equal expected, result
  end

  def test_paragraph_field_render_without_placeholder
    field_type, params, expected = load_paragraph_object(:placeholder)
    result = Admin::CannedForm::Constructor.new(params).safe_send("#{field_type}_element")
    assert_equal expected, result
  end

  def test_paragraph_field_render
    field_type, params, expected = load_paragraph_object
    result = Admin::CannedForm::Constructor.new(params).safe_send("#{field_type}_element")
    assert_equal expected, result
  end


  def test_dropdown_field_render_without_label
    field_type, params, expected = load_dropdown_object(:label)
    result = Admin::CannedForm::Constructor.new(params).safe_send("#{field_type}_element")
    assert_equal expected, result
  end

  def test_dropdown_field_render_without_choices
    field_type, params, expected = load_dropdown_object(:choices)
    result = Admin::CannedForm::Constructor.new(params).safe_send("#{field_type}_element")
    assert_equal expected, result
  end

  def test_dropdown_field_render
    field_type, params, expected = load_dropdown_object
    result = Admin::CannedForm::Constructor.new(params).safe_send("#{field_type}_element")
    assert_equal expected, result
  end

  private

    def load_text_field_object(delete_attr = nil)
      field = text_payload.deep_symbolize_keys
      field_type = field[:name].split('_')[0]
      case delete_attr
      when :label
        field.delete :label
      when :placeholder
        field.delete :placeholder
      end
      params = {
        field: field,
        object_name: OBJECT_NAME,
        disabled: false
      }
      placeholder = field[:placeholder].present? ? format(PLACEHOLDER, field_placeholder: field[:placeholder]) : ''
      text_element = format(TEXT_ELEMENT, field_name: field[:name], field_type: field_type, placeholder: placeholder)
      label =  format(LABEL_ELEMENT, field_name: field[:name], field_label: field[:label])
      expected = label + text_element
      [field_type, params, expected]
    end

    def load_checkbox_object(delete_attr = nil)
      field = checkbox_payload.deep_symbolize_keys
      field_type = field[:name].split('_')[0]
      field.delete :label if delete_attr == :label
      params = {
        field: field,
        object_name: OBJECT_NAME,
        disabled: false
      }
      checkbox_element = format(CHECKBOX_ELEMENT, field_name: field[:name], field_type: field_type)
      label =  format(LABEL_ELEMENT, field_name: field[:name], field_label: field[:label])
      expected = label + checkbox_element
      [field_type, params, expected]
    end

    def load_paragraph_object(delete_attr = nil)
      field = paragraph_payload.deep_symbolize_keys
      field_type = field[:name].split('_')[0]
      case delete_attr
      when :label
        field.delete :label
      when :placeholder
        field.delete :placeholder
      end
      params = {
        field: field,
        object_name: OBJECT_NAME,
        disabled: false
      }
      placeholder = field[:placeholder].present? ? format(PLACEHOLDER, field_placeholder: field[:placeholder]) : nil
      paragraph_element = format(PARAGRAPH_ELEMENT, field_name: field[:name], field_type: field_type, placeholder: placeholder)
      label =  format(LABEL_ELEMENT, field_name: field[:name], field_label: field[:label])
      expected = label + paragraph_element
      [field_type, params, expected]
    end

    def load_dropdown_object(delete_attr = nil)
      field = dropdown_payload.deep_symbolize_keys
      field_type = field[:name].split('_')[0]
      field.delete :label if delete_attr == :label
      field.delete :choices if delete_attr == :choices
      params = {
        field: field,
        object_name: OBJECT_NAME,
        disabled: false
      }
      choices = ""
      field[:choices].each do |choice|
        choices += format(CHOICE, choice: choice[:value])
      end
      choices = choices.present? ? choices : "\n"
      dropdown_element = format(DROPDOWN_ELEMENT, field_name: field[:name], field_type: field_type, choices: choices)
      label =  format(LABEL_ELEMENT, field_name: field[:name], field_label: field[:label])
      expected = label + dropdown_element
      [field_type, params, expected]
    end
end