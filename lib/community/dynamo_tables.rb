module Community::DynamoTables
  MODERATION_CLASSES	= [
    [ForumSpam , ForumSpamMethods],
    [ForumUnpublished, ForumSpamMethods],
    [SpamCounter, SpamCounterMethods]
  ]

  def self.create
    construct(args_for((Time.now + 2.months).utc))
    activate(args_for((Time.now + 1.months).utc))
  end

  def self.construct(args)
    @failed = []
    MODERATION_CLASSES.map do |moderation_class|
      create_table(table_class(moderation_class, args))
    end

    ForumErrorsMailer.table_operation_failed(:errors => @failed) unless @failed.blank?
  end

  def self.activate(args)
    MODERATION_CLASSES.map do |moderation_class|
      increase_throughput(table_class(moderation_class, args))
    end
  end

  def self.drop
    retire(args_for((Time.now - 1.months).utc))
    delete(args_for((Time.now - 2.months).utc))
  end

  def self.retire(args)
    MODERATION_CLASSES.map do |moderation_class|
      decrease_throughput(table_class(moderation_class, args))
    end
  end

  def self.delete(args)
    @status = []
    MODERATION_CLASSES.map do |moderation_class|
      drop_table(table_class(moderation_class, args))
    end

    ForumErrorsMailer.table_operation_failed(:errors => @status) unless @status.blank?
    clear_attachments(args) if @status.blank?
  end

  private

  def self.table_class(moderation_class, args)
    current = Class.new(Dynamo) do  
      include moderation_class[1]

      def self.initialize(current_class, args)
        @current_class = current_class
        @args = args
      end

      def self.table_name
        prefix = @current_class.table_name.split(Rails.env[0..3]).first
        %{#{prefix}#{Rails.env[0..3]}_#{(Time.new(@args[:year], @args[:month])).strftime('%Y_%m')}}
      end
    end

    current.initialize(moderation_class[0], args)
    return current

    rescue Exception => e
      puts "** Exception for #{current.table_name} **"
      puts e
  end

  def self.increase_throughput(table_class)
    puts "** increasing throughput for table ** #{table_class.table_name} **"
    current_class = table_class.instance_variable_get(:@current_class)
    if table_class.update_throughput(current_class.read_capacity, current_class.write_capacity)
      puts "** Done ** #{table_class.table_name} **"
    else
      puts "** Increase throughput Failed ** #{table_class.table_name} **"
    end
    rescue Exception => e
      puts "** Exception while increasing throughput for #{table_class.table_name} **"
      puts e
  end

  def self.decrease_throughput(table_class)
    puts "** decreasing throughput for table ** #{table_class.table_name} **"
    current_class = table_class.instance_variable_get(:@current_class)
    if table_class.update_throughput(current_class.inactive_capacity, current_class.inactive_capacity)
      puts "** decrease throughput Done ** #{table_class.table_name} **"
    else
      puts "** Decrease throughput Failed ** #{table_class.table_name} **"
    end
  rescue Exception => e
    puts "** Exception while decreasing throughput for #{table_class.table_name} **"
    puts e
  end

  def self.create_table(table)
    puts "** Creating table ** #{table.table_name} **" 
    if table.create_table
      puts "** Done ** #{table.table_name} **"
    else
      puts "** Failed ** #{table.table_name} **"
      @failed << "Failed creation of Table - #{table.table_name}"
    end
  rescue Exception => e
    @failed << "Failed creation of Table - #{table.table_name}"
    puts "** Exception while creating table #{table.table_name} **"
    puts e
  end

  def self.drop_table(table)
    puts "** dropping table ** #{table.table_name} **"
    if table.drop_table
      puts "** Done ** #{table.table_name} **"
    else
      puts "** Failed ** #{table.table_name} **"
      @status << "Failed dropping of Table - #{table.table_name}"
    end
  rescue Exception => e
    @status << "Failed dropping of Table - #{table.table_name}"
    puts "** Exception while dropping table #{table.table_name} **"
    puts e
  end

  def self.args_for(timestamp)
    {:year => timestamp.year, :month => timestamp.month }
  end

  def self.clear_attachments(args)
    begin
      bucket = AWS::S3::Bucket.new(S3_CONFIG[:bucket])
        time = Time.new(args[:year], args[:month])
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