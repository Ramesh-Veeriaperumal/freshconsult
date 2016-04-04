module CustomFields
  module Constants
    MAX_DEFAULT_FIELDS = 1000

    CUSTOM_FIELD_PROPS = {  
      :custom_text            => { :type => 1001, :dom_type => :text,           :db_column_type => :varchar_255 },
      :custom_phone_number    => { :type => 1002, :dom_type => :phone_number,   :db_column_type => :varchar_255 },
      :custom_dropdown        => { :type => 1003, :dom_type => :dropdown_blank, :db_column_type => :varchar_255 },
      :custom_number          => { :type => 1004, :dom_type => :number,         :db_column_type => :integer_11 },
      :custom_survey_radio    => { :type => 1005, :dom_type => :survey_radio,   :db_column_type => :integer_11 },
      :custom_checkbox        => { :type => 1006, :dom_type => :checkbox,       :db_column_type => :tiny_int_1 },
      :custom_date            => { :type => 1007, :dom_type => :date,           :db_column_type => :date_time },
      :custom_paragraph       => { :type => 1008, :dom_type => :paragraph,      :db_column_type => :text },
      :custom_url             => { :type => 1009, :dom_type => :url,            :db_column_type => :text }
    }

    TIME_ZONE_CHOICES = ActiveSupport::TimeZone.all.map do |time_zone| [time_zone.to_s, time_zone.name.to_sym] end
  end
end
