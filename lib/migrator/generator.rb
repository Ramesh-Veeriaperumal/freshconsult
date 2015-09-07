class Migrator::Generator < Lhm::Entangler
  def trigger(type)
    "create_#{ type }_#{ @origin.name }"
  end

  def entangle
    [
      create_insert_trigger,
      create_update_trigger,
      create_delete_trigger
    ]
  end

  def untangle
    [
      "drop trigger if exists `#{ trigger(:del) }`",
      "drop trigger if exists `#{ trigger(:ins) }`",
      "drop trigger if exists `#{ trigger(:upd) }`"
    ]
  end

  def create_insert_trigger
    strip %Q{
      create trigger `#{ trigger(:ins) }`
      after insert on `#{ @origin.name }` for each row
      replace into `#{ @destination.name }` (#{ common_joined })
      values (#{ typed("NEW",common) })
    }
  end

  def create_update_trigger
    strip %Q{
      create trigger `#{ trigger(:upd) }`
      after update on `#{ @origin.name }` for each row
      replace into `#{ @destination.name }` (#{ common_joined }) 
      values (#{ typed("NEW",common) })
    }
  end

  def create_delete_trigger
    strip %Q{
      create trigger `#{ trigger(:del) }`
      after delete on `#{ @origin.name }` for each row
      delete ignore from `#{ @destination.name }` 
      where `#{ @destination.name }`.`id` = OLD.`id`
    }
  end

  def common
    (columns(@origin.name) & columns(@destination.name)).sort
  end

  def common_joined
    escaped.join(", ")
  end

  def escaped
    common.map { |name| tick(name)  }
  end

  def columns(table_name)
    ActiveRecord::Base.connection.columns(table_name).map {|c| c.name}
  end

  def typed(type,common)
    common.map { |name| qualified(name, type)  }.join(", ")
  end

  def before
    entangle.each do |sql|
      ActiveRecord::Base.connection.execute(sql)
    end
  end

  def after
    untangle.each do |sql|
      ActiveRecord::Base.connection.execute(sql)
    end
  end

  def self.trigger_generate(current_table,next_table)
    origin = Lhm::Table.new(current_table)
    destination = Lhm::Table.new(next_table)
    migration = Lhm::Migration.new(origin, destination)
    entangler = Migrator::Generator.new(migration)
    entangler.before
  end

  private

    def qualified(name, type)
      "#{ type }.`#{ name }`"
    end

    def tick(name)
      "`#{ name }`"
    end
end