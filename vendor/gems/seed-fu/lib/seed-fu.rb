module SeedFu
  
  class PopulateSeed

     def self.populate
      if ENV["FIXTURE_PATH"]
        perform(ENV["FIXTURE_PATH"])
      else
        populate_foreground
        populate_background
      end
    end

    def self.populate_foreground
      foreground_jobs_fixture_path = "db/fixtures/foreground"
      perform(foreground_jobs_fixture_path)
    end

    def self.populate_background
      background_jobs_fixture_path = "db/fixtures/background"
      perform(background_jobs_fixture_path)
    end

    def self.populate_sandbox
      sandbox_jobs_fixture_path = "db/fixtures/sandbox"
      perform(sandbox_jobs_fixture_path)
    end

    def self.perform fixture_path  

      seed_files = (
        ( Dir[File.join(Rails.root, fixture_path, '*.rb')] +
          Dir[File.join(Rails.root, fixture_path, '*.rb.gz')] ).sort +
        ( Dir[File.join(Rails.root, fixture_path, Rails.env, '*.rb')] +
          Dir[File.join(Rails.root, fixture_path, Rails.env, '*.rb.gz')] ).sort
      ).uniq
      
      if ENV["SEED"]
        filter = ENV["SEED"].gsub(/,/, "|")
        seed_files.reject!{ |file| !(file =~ /#{filter}/) }
        Rails.logger.debug "\n == Filtering seed files against regexp: #{filter}"
      end
  
      seed_files.each do |file|
        pretty_name = file.sub("#{Rails.root}/", "")
        Rails.logger.debug "\n== Seed from #{pretty_name} " + ("=" * (60 - (17 + File.split(file).last.length)))
  
        old_level = ActiveRecord::Base.logger.level
        begin
          #ActiveRecord::Base.logger.level = 7
  
          ActiveRecord::Base.transaction do
            if pretty_name[-3..pretty_name.length] == '.gz'
              # If the file is gzip, read it and use eval
              #
              Zlib::GzipReader.open(file) do |gz|
                chunked_ruby = ''
                gz.each_line do |line|
                  if line == "# BREAK EVAL\n"
                    eval(chunked_ruby, binding, __FILE__, __LINE__)
                    chunked_ruby = ''
                  else
                    chunked_ruby << line
                  end
                end
                eval(chunked_ruby, binding, __FILE__, __LINE__) unless chunked_ruby == ''
              end
            else
              # Just load regular .rb files
              #
              File.open(file) do |file|
                puts "Processing fixtures file - #{file.inspect}"
                chunked_ruby = ''
                file.each_line do |line|
                  if line == "# BREAK EVAL\n"
                    eval(chunked_ruby, binding, __FILE__, __LINE__)
                    chunked_ruby = ''
                  else
                    chunked_ruby << line
                  end
                end
                eval(chunked_ruby, binding, __FILE__, __LINE__) unless chunked_ruby == ''
              end
            end
          end
        rescue Exception => e
          p e
          Rails.logger.debug "Exception #{e.inspect} occurred while processing fixtures file - #{file.inspect}"
          raise e
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
        record.safe_send("#{k}=", v)
      end
      raise "Error Saving: #{record.inspect}" unless record.save
      Rails.logger.debug " - #{@model_class} #{condition_hash.inspect}"      
      record
    end

    def method_missing(method_name, *args) #:nodoc:
      if args.size == 1 and (match = method_name.to_s.match(/(.*)=$/))
        self.class.class_eval "def #{method_name} arg; @data[:#{match[1]}] = arg; end"
        safe_send(method_name, args[0])
      else
        super
      end
    end

    protected

    def get
      records = @model_class.where(condition_hash)
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
require File.dirname(__FILE__) + "/../rails/init"
