module Helpdesk::Mysql
  module Util
    def self.table_name_extension(table_name)
      table_name + current_week
    end

    def self.next_week_table_extension(table_name)
      table_name + next_week
    end

    def self.current_week
      name_format(Time.now.utc.beginning_of_week)
    end

    def self.next_week
      name_format((Time.now.utc + 7.days).utc.beginning_of_week)
    end

    def self.monthly
      name_format(Time.now.utc.beginning_of_month)
    end

    def self.name_format(time)
      return time.strftime("_%Y_%m_%d")
    end

  end
end
