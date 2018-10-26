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

    OVERRIDE_OPERATOR_LABEL = {
      :in => 'is',
      :not_in => 'is_not'
    }.freeze

    OPERATOR_LIST =  [
      :is,
      :is_not,
      :contains,
      :does_not_contain,
      :starts_with,
      :ends_with,
      :between,
      :between_range,
      :selected,
      :not_selected,
      :less_than,
      :greater_than,
      :during,
      :in,
      :not_in,
      :and
    ].map { |i| [i, OVERRIDE_OPERATOR_LABEL[i] || i.to_s] }.freeze

    ALTERNATE_LABEL = [
        [ :in, 'admin.va_rules.label.object_id_array_in' ],
        [ :and, 'admin.va_rules.label.object_id_array_and' ],
        [ :not_in, 'admin.va_rules.label.object_id_array_not_in' ]
    ]

    NOT_OPERATORS = ['is_not', 'does_not_contain', 'not_selected', 'not_in']
    
    AUTOMATIONS_MAIL_NAME = "automations rule"

    AVAILABLE_LOCALES = I18n.available_locales_with_name.map{ |a| a.reverse }

    AVAILABLE_TIMEZONES = ActiveSupport::TimeZone.all.map { |time_zone| [time_zone.name.to_sym, time_zone.to_s] }

    MAX_CUSTOM_HEADERS = 5

    MAX_ACTION_DATA_LIMIT = 63000

    QUERY_OPERATOR = {
        :is => 'IS', :is_not => 'IS NOT', :in => 'IN',
        :not_in => 'NOT IN', :equal => '=', :not_equal => '!=',
        :greater_than => '>', :less_than => '<',
        :greater_than_equal_to => '>=', :less_than_equal_to => '<=',
        :not_equal_to => '<>', :like => 'LIKE', :not => 'NOT', :or => 'OR',
        :AND => 'AND'
    }

    NULL_QUERY = "%{db_column} IS NULL"

    NOT_NULL_QUERY = "%{db_column} IS NOT NULL"

    ANY_VALUE = {
        :with_none => "--",
        :without_none => "##"
    }

    def va_alternate_label
      va_alternate_label = {
        :object_id_array => Hash[*ALTERNATE_LABEL.map { |i, j| [i, I18n.t(j)] }.flatten]
      }
    end

    def va_operator_list
      Hash[*OPERATOR_LIST.map { |i, j| [i, I18n.t(j)] }.flatten]
    end
  end
end
