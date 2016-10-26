module Va
  module Constants
    
    OPERATOR_TYPES = {
      :email       => [ "is", "is_not", "contains", "does_not_contain" ],
      :text        => [ "is", "is_not", "contains", "does_not_contain", "starts_with", "ends_with" ],
      :checkbox    => [ "selected", "not_selected" ],
      :choicelist  => [ "in", "not_in" ],
      :number      => [ "is", "is_not", "greater_than", "less_than" ],
      :decimal     => [ "is", "is_not", "greater_than", "less_than" ],
      :hours       => [ "is", "greater_than", "less_than" ],
      :nestedlist  => [ "is" ],
      :greater     => [ "greater_than" ],
      :object_id   => [ "in", "not_in"],
      :date_time   => [ "during" ],
      :date        => [ "is" , "is_not", "greater_than", "less_than" ],
      :object_id_array  => [ "in", "and", "not_in" ]
    }

    CF_OPERATOR_TYPES = {
      "custom_dropdown" => "choicelist",
      "custom_checkbox" => "checkbox",
      "custom_number"   => "number",
      "custom_decimal"  => "decimal",
      "nested_field"    => "nestedlist",
      "custom_date"     => "date"
    }

    CF_CUSTOMER_TYPES = {
      "custom_dropdown"     => "choicelist",
      "custom_checkbox"     => "checkbox",
      "custom_number"       => "number",
      "custom_url"          => "text",
      "custom_phone_number" => "text",
      "custom_paragraph"    => "text",
      "custom_date"         => "date"
    }

    OPERATOR_LIST =  {
      :is                =>  I18n.t('is'),
      :is_not            =>  I18n.t('is_not'),
      :contains          =>  I18n.t('contains'),
      :does_not_contain  =>  I18n.t('does_not_contain'),
      :starts_with       =>  I18n.t('starts_with'),
      :ends_with         =>  I18n.t('ends_with'),
      :between           =>  I18n.t('between'),
      :between_range     =>  I18n.t('between_range'),
      :selected          =>  I18n.t('selected'),
      :not_selected      =>  I18n.t('not_selected'),
      :less_than         =>  I18n.t('less_than'),
      :greater_than      =>  I18n.t('greater_than'),
      :during            =>  I18n.t('during'),
      :in                =>  I18n.t('is'),
      :not_in            =>  I18n.t('is_not'),
      :and               =>  I18n.t('and')
    }

    ALTERNATE_LABEL = {
      :object_id_array => {:in     => I18n.t('admin.va_rules.label.object_id_array_in'),
                      :and    => I18n.t('admin.va_rules.label.object_id_array_and'),
                      :not_in => I18n.t('admin.va_rules.label.object_id_array_not_in')}
    }

    NOT_OPERATORS = ['is_not', 'does_not_contain', 'not_selected', 'not_in']
    
    AUTOMATIONS_MAIL_NAME = "automations rule"

    AVAILABLE_LOCALES = I18n.available_locales_with_name.map{ |a| a.reverse }

    AVAILABLE_TIMEZONES = ActiveSupport::TimeZone.all.map { |time_zone| [time_zone.name.to_sym, time_zone.to_s] }

    MAX_CUSTOM_HEADERS = 5 
  end
end
