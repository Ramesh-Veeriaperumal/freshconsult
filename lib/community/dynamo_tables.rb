module Community::DynamoTables

  include Community::Moderation::Constants

  MODERATION_MODULES_BY_CLASS	= [
    [ForumSpam , ForumSpamMethods],
    [ForumUnpublished, ForumSpamMethods],
    [SpamCounter, SpamCounterMethods]
  ]

  MODERATION_CLASSES = MODERATION_MODULES_BY_CLASS.map { |mc| mc[0] }

  NEXT_MODERATION_CLASSES = [ ForumSpamNext, ForumUnpublishedNext, SpamCounterNext ]

  def self.create(args = {})
    @failed = []
    MODERATION_MODULES_BY_CLASS.each do |klass|
      new_table = Class.new(Dynamo) do 

        include klass[1]

        def self.initialize(current_class, args)
          @current_class = current_class
          @args = args
        end

        def self.table_name
          if @args.blank?
            @current_class.afternext
          else
            prefix = @current_class.table_name.split(Rails.env[0..3]).first
            %{#{prefix}#{Rails.env[0..3]}_#{(Time.new(@args[:year], @args[:month])).strftime('%Y_%m')}}
          end
        end
      end

      new_table.initialize(klass[0],args)

      puts "** Got ** #{new_table.table_name} **" 
      if new_table.create_table
        puts "** Done ** #{new_table.table_name} **"
      else
        @failed << "Creation of Table - #{new_table.table_name}"
        puts "** Failed ** #{new_table.table_name} **"
      end
    end

    increase_throughput if args.blank? && (Rails.env != "test")
    ForumErrorsMailer.table_creation_failed(:errors => @failed) unless @failed.blank?
  end

  def self.increase_throughput 
    NEXT_MODERATION_CLASSES.each do |klass|
      begin
        if klass.update_throughput(DYNAMO_THROUGHPUT[:read], DYNAMO_THROUGHPUT[:write])
          puts "** Done ** #{klass.table_name} **"
        else
          @failed << "Updating Throughput of Table - #{klass.table_name}"
          puts "** Failed ** #{klass.table_name} **"
        end
      rescue Exception => e
        @failed << "Exception while Updating Throughput of Table - #{klass.table_name}"
        puts "** Exception while updating throughput for #{klass.table_name} **"
        puts e
      end
    end
  end

  def self.drop(args = {})
  	@drop_status = []
  	MODERATION_CLASSES.map do |moderation_class|
      current_previous = Class.new(Dynamo) do  

        def self.initialize(current_class, args)
          @current_class = current_class
          @args = args
        end

        def self.table_name
          if @args.blank?
            @current_class.previous
          else
            prefix = @current_class.table_name.split(Rails.env[0..3]).first
            %{#{prefix}#{Rails.env[0..3]}_#{(Time.new(@args[:year], @args[:month])).strftime('%Y_%m')}}
          end
        end
      end

      current_previous.initialize(moderation_class, args)

      retire_table(current_previous)
    end
    clear_attachments(args) unless @drop_status.include?(false)
  end

  def self.retire_table(table_class)
    unless Rails.env == "test"
      begin
        if table_class.update_throughput(DYNAMO_THROUGHPUT[:inactive], DYNAMO_THROUGHPUT[:inactive])
          puts "** Update throughput Done ** #{table_class.table_name} **"
        else
          puts "** Update throughput Failed ** #{table_class.table_name} **"
        end
      rescue Exception => e
        puts "** Exception while updating throughput for #{table_class.table_name} **"
        puts e
      end
    else
      # As a temp. thing, the tables will not be dropped in staging/prodn environments.
      # After stability is ensured, this will be the default irrespective of env.
      puts "** Got ** #{table_class.table_name} **"
      if table_class.drop_table
        puts "** Done ** #{table_class.table_name} **"
        @drop_status << true
      else
        puts "** Failed ** #{table_class.table_name} **"
        @drop_status << false
      end
    end
  end

  def self.clear_attachments(args)
    begin
      bucket = AWS::S3::Bucket.new(S3_CONFIG[:bucket])
      if args.blank?
      	time = (Time.now - 1.months).utc
      else
        time = Time.new(args[:year], args[:month])
      end
      prefix = %{spam_attachments/month_#{time.strftime('%Y_%m')}}
      puts "** Got ** #{prefix} **" 
      bucket.objects.with_prefix(prefix).delete_all
      puts "** Done ** #{prefix} **" 
    rescue Exception => e
      puts e
      puts "** Failed ** #{prefix} **" 
    end
  end
end	