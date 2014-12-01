module CustomFields
  module Migrations
    
    class CustomFieldData < ActiveRecord::Base # for DB connection object
      def self.create_table options
        self.connection.create_table options[:table_name] do |t|
          t.column :account_id, "bigint unsigned"
          t.column options[:custom_form_id], "bigint unsigned"
          t.column options[:foreign_key], "bigint unsigned"
          t.timestamps
          1.upto(options[:string_fields].to_i)  {|i| t.string   "cf_str" + (i < 10 ? "0#{i}" : "#{i}")}
          1.upto(options[:text_fields].to_i)    {|j| t.text     "cf_text" + (j < 10 ? "0#{j}" : "#{j}")}
          1.upto(options[:integer_fields].to_i) {|k| t.integer  "cf_int" + (k < 10 ? "0#{k}" : "#{k}")}
          1.upto(options[:date_fields].to_i)    {|l| t.datetime "cf_date" + (l < 10 ? "0#{l}" : "#{l}")}
          1.upto(options[:boolean_fields].to_i) {|m| t.boolean  "cf_boolean" + (m < 10 ? "0#{m}" : "#{m}")}
          1.upto(options[:decimal_fields].to_i) {|m| t.decimal  "cf_decimal" + (m < 10 ? "0#{m}" : "#{m}")}
        end

        self.connection.add_index options[:table_name], [:account_id, options[:foreign_key]],
          :unique => true # since :foreign_key is not polymorphic now
        self.connection.add_index options[:table_name], [:account_id, options[:custom_form_id]] # for NullifyDeletedContactFieldData
      end
    end

  end
end