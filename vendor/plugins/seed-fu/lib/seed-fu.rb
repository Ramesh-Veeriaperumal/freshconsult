module SeedFu
  
  class PopulateSeed
    def self.populate
      fixture_path = ENV["FIXTURE_PATH"] ? ENV["FIXTURE_PATH"] : "db/fixtures"
  
      seed_files = (
        ( Dir[File.join(RAILS_ROOT, fixture_path, '*.rb')] +
          Dir[File.join(RAILS_ROOT, fixture_path, '*.rb.gz')] ).sort +
        ( Dir[File.join(RAILS_ROOT, fixture_path, RAILS_ENV, '*.rb')] +
          Dir[File.join(RAILS_ROOT, fixture_path, RAILS_ENV, '*.rb.gz')] ).sort
      ).uniq
      
      if ENV["SEED"]
        filter = ENV["SEED"].gsub(/,/, "|")
        seed_files.reject!{ |file| !(file =~ /#{filter}/) }
        puts "\n == Filtering seed files against regexp: #{filter}"
      end
  
      seed_files.each do |file|
        pretty_name = file.sub("#{RAILS_ROOT}/", "")
        puts "\n== Seed from #{pretty_name} " + ("=" * (60 - (17 + File.split(file).last.length)))
  
        old_level = ActiveRecord::Base.logger.level
        begin
          ActiveRecord::Base.logger.level = 7
  
          ActiveRecord::Base.transaction do
            if pretty_name[-3..pretty_name.length] == '.gz'
              # If the file is gzip, read it and use eval
              #
              Zlib::GzipReader.open(file) do |gz|
                chunked_ruby = ''
                gz.each_line do |line|
                  if line == "# BREAK EVAL\n"
                    eval(chunked_ruby)
                    chunked_ruby = ''
                  else
                    chunked_ruby << line
                  end
                end
                eval(chunked_ruby) unless chunked_ruby == ''
              end
            else
              # Just load regular .rb files
              #
              File.open(file) do |file|
                chunked_ruby = ''
                file.each_line do |line|
                  if line == "# BREAK EVAL\n"
                    eval(chunked_ruby)
                    chunked_ruby = ''
                  else
                    chunked_ruby << line
                  end
                end
                eval(chunked_ruby) unless chunked_ruby == ''
              end
            end
          end
  
        ensure
          ActiveRecord::Base.logger.level = old_level
        end
      end
    end
  end

  class Seeder
    def self.plant(model_class, *constraints, &block)
      constraints = [:id] if constraints.empty?
      seed = Seeder.new(model_class)
      insert_only = constraints.last.is_a? TrueClass
      constraints.delete_at(*constraints.length-1) if (constraints.last.is_a? TrueClass or constraints.last.is_a? FalseClass)
      seed.set_constraints(*constraints)
      yield seed
      seed.plant!(insert_only)
    end

    def initialize(model_class)
      @model_class = model_class
      @constraints = [:id]
      @data = {}
    end

    def set_constraints(*constraints)
      raise "You must set at least one constraint." if constraints.empty?
      @constraints = []
      constraints.each do |constraint|
        raise "Your constraint `#{constraint}` is not a column in #{@model_class}. Valid columns are `#{@model_class.column_names.join("`, `")}`." unless @model_class.column_names.include?(constraint.to_s)
        @constraints << constraint.to_sym
      end
    end

    def plant! insert_only=false
      record = get
      return if !record.new_record? and insert_only
      @data.each do |k, v|
        record.send("#{k}=", v)
      end
      raise "Error Saving: #{record.inspect}" unless record.save
      puts " - #{@model_class} #{condition_hash.inspect}"      
      record
    end

    def method_missing(method_name, *args) #:nodoc:
      if args.size == 1 and (match = method_name.to_s.match(/(.*)=$/))
        self.class.class_eval "def #{method_name} arg; @data[:#{match[1]}] = arg; end"
        send(method_name, args[0])
      else
        super
      end
    end

    protected

    def get
      records = @model_class.find(:all, :conditions => condition_hash)
      raise "Given constraints yielded multiple records." unless records.size < 2
      if records.any?
        return records.first
      else
        return @model_class.new
      end
    end

    def condition_hash
      @constraints.inject({}) {|a,c| a[c] = @data[c]; a }
    end
  end
end


class ActiveRecord::Base
  # Creates a single record of seed data for use
  # with the db:seed rake task. 
  # 
  # === Parameters
  # constraints :: Immutable reference attributes. Defaults to :id
  def self.seed(*constraints, &block)
    SeedFu::Seeder.plant(self, *constraints, &block)
  end
  
  def self.seed_once(*constraints, &block)
    constraints << true
    SeedFu::Seeder.plant(self, *constraints, &block)
  end

  def self.seed_many(*constraints)
    seeds = constraints.pop
    seeds.each do |seed_data|
      seed(*constraints) do |s|
        seed_data.each_pair do |k,v|
          s.send "#{k}=", v
        end
      end
    end
  end
end
