# TODO: need to write test cases
module Helpdesk::Mysql
  module Util
    def self.table_name_extension_weekly(table_name)
      table_name + current_week
    end

    def self.table_name_extension_monthly(table_name)
      table_name + current_month
    end

    def self.next_week_table_extension(table_name)
      table_name + next_week
    end

    def self.next_month_table_extension(table_name)
      table_name + next_month
    end

    def self.previous_month_table_extension(table_name)
      table_name + previous_month
    end

    def self.current_week
      name_format(Time.now.utc.beginning_of_week)
    end

    def self.next_week
      name_format((Time.now.utc + 7.days).utc.beginning_of_week)
    end

    def self.current_month
      name_format_only_month_year(Time.now.utc.beginning_of_month)
    end

    def self.next_month
      name_format_only_month_year(Time.now.utc.end_of_month + 1.day)
    end

    def self.previous_month
      name_format_only_month_year(Time.now.utc.beginning_of_month - 1.day)
    end

    def self.name_format(time)
      return time.strftime("_%Y_%m_%d")
    end

    def self.name_format_only_month_year(time)
      return time.strftime("_%Y_%m")
    end

  end
end
