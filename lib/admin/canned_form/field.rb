class Admin::CannedForm::Field
  extend Inherits::Field
  inherits_field field_choice_class: 'Admin::CannedForm::FieldChoice',
                 form_id: 'account_form_id'
end
