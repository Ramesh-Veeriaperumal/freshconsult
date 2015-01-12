module Va
  module Constants
    
    OPERATOR_TYPES = {
      :email       => [ "is", "is_not", "contains", "does_not_contain" ],
      :text        => [ "is", "is_not", "contains", "does_not_contain", "starts_with", "ends_with" ],
      :checkbox    => [ "selected", "not_selected" ],
      :choicelist  => [ "is", "is_not" ],
      :number      => [ "is", "is_not" ],
      :decimal     => [ "is", "is_not" ],
      :hours       => [ "is", "greater_than", "less_than" ],
      :nestedlist  => [ "is" ],
      :greater     => [ "greater_than" ],
      :object_id   => [ "is", "is_not"],
      :date_time   => [ "during" ],
      :date        => [ "is" , "is_not", "greater_than", "less_than" ],
      :number_for_contacts => [ "is", "is_not", "greater_than", "less_than" ]
    }

    CF_OPERATOR_TYPES = {
      "custom_dropdown" => "choicelist",
      "custom_checkbox" => "checkbox",
      "custom_number"   => "number",
      "custom_decimal"  => "decimal",
      "nested_field"    => "nestedlist"
    }

    CF_CUSTOMER_TYPES = {
      "custom_dropdown"     => "choicelist",
      "custom_checkbox"     => "checkbox",
      "custom_number"       => "number_for_contacts",
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
      :during            =>  I18n.t('during')
    }

    AUTOMATIONS_MAIL_NAME = "automations rule"

    AVAILABLE_LOCALES = I18n.available_locales_with_name.map{ |a| a.reverse }

    AVAILABLE_TIMEZONES = ActiveSupport::TimeZone.all.map { |time_zone| [time_zone.name.to_sym, time_zone.to_s] }
  end
end
