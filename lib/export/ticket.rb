class Export::Ticket < Struct.new(:export_params)
  include Helpdesk::Ticketfields::TicketStatus
  include ExportCsvUtil
  include Rails.application.routes.url_helpers
  include Export::Util
  include Redis::RedisKeys
  include Helpdesk::TicketModelExtension
  include ArchiveTicketEs
  include Silkroad::Export::FeatureCheck
  include AdvancedTicketScopes
  DATE_TIME_PARSE = [:created_at, :due_by, :resolved_at, :updated_at, :first_response_time, :closed_at].freeze
  ERB_PATH = Rails.root.join('app/views/support/tickets/export/%<file_name>s.xls.erb').to_path
  FILE_FORMAT = ['csv', 'xls'].freeze
  BATCH_SIZE = 100
  DISASSOCIATED_MODELS = {
    archive_tickets: [:ticket_states]
  }.freeze
  TICKET_STATE_FILTER = TicketConstants::STATES_HASH.keys.map(&:to_s)

  def perform
    begin
      initialize_params
      validate_ticket_state_filter if export_params.key? :ticket_state_filter
      set_current_user
      data_export_type = export_params[:archived_tickets] ? 'archive_ticket' : 'ticket'
      create_export data_export_type
      @file_path = generate_file_path("#{@data_export.id}_#{data_export_type}", export_params[:format])
      add_url_to_export_fields if export_params[:add_url]
      set_all_agent_groups_permission
      Sharding.run_on_slave { export_tickets }
      if @no_tickets
        send_no_ticket_email
      else
        upload_file(@file_path)
        if send_to_silkroad?(export_params)
          Rails.logger.info 'Silkroad Shadow Mode Started'
          silkroad_params = export_params.merge(helpkit_export_id: @data_export.id)
          silkroad_data_export = Silkroad::Export::Ticket.new.create_job(silkroad_params)
          custom_export_logger.info logging_format(silkroad_data_export) if silkroad_data_export && custom_export_logger.present?
        end
        DataExportMailer.send_email(:ticket_export, email_params[:user], email_params)
      end
    rescue Exception => e
      NewRelic::Agent.notice_error(e)
      Rails.logger.debug "Error  ::#{e.message}\n#{e.backtrace.join("\n")}"
      @data_export.failure!(e.message + "\n" + e.backtrace.join("\n"))
      DataExportMailer.send_email(:export_failure, email_params[:user], email_params)
    end
  ensure
    # Moving data exports entry to failed status in case of any failures
    if !@data_export.destroyed? && @data_export.status == DataExport::EXPORT_STATUS[:started]
      Rails.logger.error "Ticket export status at the end of export job :: #{@data_export.status}"
      @data_export.failure!('Export::Failed')
      DataExportMailer.send_email(:export_failure, email_params[:user], email_params)
    end
    schedule_export_cleanup(@data_export, data_export_type) if @data_export.present?
  end

  def self.enqueue(export_params)
    # Not using the methods in RedisOthers to avoid the include /extend problem
    # class methods vs instance methods issue.
    export_params = export_params.except(:authenticity_token, :action, :controller, :utf8)
    Tickets::Export::TicketsExport.perform_async(export_params)
  end

  protected

    def initialize_params
      export_params.symbolize_keys!
      export_fields = export_params[:export_fields]
      export_params[:export_fields] = reorder_export_params export_fields
      export_params[:format] = FILE_FORMAT[0] unless FILE_FORMAT.include? export_params[:format]
      delete_invisible_fields
      format_contact_company_params
      @export_stats = { number_of_records: 0 }
    end

    def validate_ticket_state_filter
      raise StandardError, 'Export::Ticket ticket_state_filter is invalid' unless TICKET_STATE_FILTER.include? export_params[:ticket_state_filter]
    end

    def add_url_to_export_fields
      export_params[:export_fields]['support_ticket_path'] = 'URL'
      @headers << 'support_ticket_path'
    end

    def export_tickets
      write_export_file(@file_path) do |file|
        safe_send("#{export_params[:format]}_ticket_export", file)
      end
    end

    def csv_ticket_export(file)
      csv_headers = @headers.collect { |header| export_params[:export_fields][header] }
      csv_headers << @contact_headers.collect { |header| export_params[:contact_fields][header] } if @contact_headers.present?
      csv_headers << @company_headers.collect { |header| export_params[:company_fields][header] } if @company_headers.present?
      csv_headers.flatten!
      write_csv(file, csv_headers)
      ticket_export_data(file)
    end

    def xls_ticket_export(file)
      require 'erb'
      @xls_hash = export_params[:export_fields]
      @contact_hash = export_params[:contact_fields] || {}
      @company_hash = export_params[:company_fields] || {}
      @contact_headers ||= []
      @company_headers ||= []
      write_xls(file, xls_erb('header'))
      @data_xls_erb = xls_erb('data')
      ticket_export_data(file)
      write_xls(file, xls_erb('footer'))
    end

    def xls_erb(file_name)
      erb_file_path = format(ERB_PATH, file_name: file_name)
      ERB.new(File.read(erb_file_path))
    end

    def ticket_export_data(file)
      @no_tickets = true
      @batch_no = 0
      if export_params[:archived_tickets].present? && export_params[:use_es].present?
        archive_tickets_from_es(export_params) do |error, records|
          if error.present?
            raise StandardError, "export::archivetickets Querying Elasticsearch failed: #{error.messages}"
          elsif records.count > 0
            build_file(records, file)
          end
        end
      elsif export_params[:archived_tickets]
        Account.current.archive_tickets.permissible(User.current).find_in_batches(archive_export_query) do |items|
          build_file(items, file)
        end
      else
        Account.current.tickets.permissible(User.current).find_in_batches(export_query) do |items|
          build_file(items, file)
        end
      end
    end

    def export_query
      {
        select: select_query,
        conditions: sql_conditions,
        joins: joins,
        batch_size: BATCH_SIZE
      }
    end

    def build_file(items, file)
      Rails.logger.debug "Processing ticket export batch :: #{@batch_no += 1}"
      @no_tickets = false
      @custom_field_names ||= Account.current.ticket_fields.custom_fields.pluck(:name)
      ActiveRecord::Associations::Preloader.new(items, preload_associations).run
      @export_stats[:number_of_records] += items.count if account.launched?(:silkroad_shadow)

      items.each do |item|
        record = []
        data = ''
        begin
          @headers.each do |val|
            data = export_params[:archived_tickets] ? fetch_field_value(item, val) : item.safe_send(val)
            record << format_data(val, data)
          end
          ['contact', 'company'].each do |type|
            assoc = type.eql?('contact') ? 'requester' : 'company'
            instance_variable_get("@#{type}_headers").each do |val|
              data = item.safe_send(assoc).respond_to?(val) ? item.safe_send(assoc).safe_send(val) : ''
              record << format_data(val, data)
            end
          end
        rescue Exception => e
          NewRelic::Agent.notice_error(e, custom_params: { ticket_id: item.id })
          Rails.logger.info "Exception in tickets export::: Ticket:: #{item}, data:: #{data}"
        end
        export_params[:format] == FILE_FORMAT[0] ? write_csv(file, record) : write_xls(file, @data_xls_erb, record)
      end
    end

    def write_xls(file, erb, record = [])
      @record = record
      file.write(erb.result(binding))
    end

    def format_data(val, data)
      @custom_date_time_fields ||= Account.current.custom_date_time_fields_from_cache.map(&:name)
      date_format = Account.current.date_type(:short_day_separated)
      if data.present?
        if DATE_TIME_PARSE.include?(val.to_sym)
          data = parse_date(data)
        elsif @custom_date_time_fields.include?(val)
          data = parse_date(data.in_time_zone(Time.zone.name))
        elsif @custom_field_names.include?(val) && data.is_a?(Time)
          data = data.utc.strftime(date_format)
        end
      end
      escape_html(strip_equal(data))
    end

    def preload_associations
      @preload_associations ||= begin
        associations = []
        @headers.each do |val|
          if @custom_field_names.include?(val)
            associations << { flexifield: { flexifield_def: :flexifield_def_entries } }
            associations << { flexifield: :denormalized_flexifield } if Account.current.denormalized_flexifields_enabled?
          elsif val.eql?('ticket_survey_results') && Account.current.new_survey_enabled?
            associations << { custom_survey_results: [:survey_result_data, { survey: { survey_default_question: [:survey, :custom_field_choices_asc, :custom_field_choices_desc] } }] }
          elsif val.eql?('product_name') && !export_params[:archived_tickets]
            associations << { schema_less_ticket: :product }
          elsif Helpdesk::TicketModelExtension::ASSOCIATION_BY_VALUE[val]
            association_model = Helpdesk::TicketModelExtension::ASSOCIATION_BY_VALUE[val]
            # skip ticket_states preload for archive tickets
            associations << association_model unless skip_association_preload(association_model)
          end
        end
        associations << :requester if @contact_headers.present?
        associations << :company if @company_headers.present?
        associations.uniq
      end
    end

    def fetch_field_value(item, field)
      item.respond_to?(field) ? item.safe_send(field) : item.custom_field_value(field)
    end

    def allowed_fields
      @allowed_fields ||= begin
        (export_fields.collect do |key|
          [key[:value]].concat(nested_fields_values(key))
        end).flatten
      end
    end

    def nested_fields_values(key)
      return [] unless key[:type] == 'nested_field'

      key[:levels].collect { |lvl| lvl[:name] }
    end

    def delete_invisible_fields
      @headers = export_params[:export_fields].keys
      @headers.delete_if { |header_key| !allowed_fields.include?(header_key) }
    end

    def format_contact_company_params
      ['contact', 'company'].each do |type|
        next if export_params["#{type}_fields".to_sym].blank?

        reorder_contact_company_fields type
        allowed_fields = contact_company_export_fields(type)
        instance_variable_set(
          "@#{type}_headers",
          export_params["#{type}_fields".to_sym].keys.delete_if { |header_key| !allowed_fields.include?(header_key.to_s) }
        )
      end
    end

    def sql_conditions
      @sql_conditions ||= begin
        @index_filter =  Account.current.ticket_filters.new(Helpdesk::Filters::CustomTicketFilter::MODEL_NAME).deserialize_from_params(export_params)
        sql_conditions = @index_filter.sql_conditions
        sql_conditions[0].concat(date_conditions)

        sql_conditions[0].concat(%(and helpdesk_tickets.status in (#{RESOLVED}, #{CLOSED}))) if export_params[:ticket_state_filter].eql?('resolved_at')
        sql_conditions[0].concat(%(and helpdesk_tickets.status in (#{CLOSED}))) if export_params[:ticket_state_filter].eql?('closed_at')
        sql_conditions
      end
    end

    def date_conditions
      if export_params[:ticket_state_filter].to_s == 'created_at'
        %(and helpdesk_tickets.created_at
          between '#{export_params[:start_date]}' and '#{export_params[:end_date]}'
        )
      else
        %(and helpdesk_ticket_states.#{export_params[:ticket_state_filter]}
          between '#{export_params[:start_date]}' and '#{export_params[:end_date]}'
        )
      end
    end

    def select_query
      # sql_conditions
      select = 'helpdesk_tickets.* '
      select = "DISTINCT(helpdesk_tickets.id) as 'unique_id' , #{select}" if sql_conditions[0].include?('helpdesk_tags.name')
      select
    end

    def joins
      all_joins = @index_filter.get_joins(sql_conditions)
      all_joins[0].concat(%( INNER JOIN helpdesk_ticket_states ON
                     helpdesk_ticket_states.ticket_id = helpdesk_tickets.id AND
                     helpdesk_tickets.account_id = helpdesk_ticket_states.account_id))
      all_joins
    end

    def send_no_ticket_email
      email_params = { user: User.current, domain: export_params[:portal_url] }
      DataExportMailer.send_email(:no_tickets, email_params[:user], email_params)
      @data_export.destroy
    end

    # Archive queries
    def archive_export_query
      {
        select: archive_select_query,
        conditions: archive_sql_conditions,
        joins: archive_joins,
        batch_size: BATCH_SIZE
      }
    end

    def archive_select_query
      select = 'archive_tickets.* '
      select = "DISTINCT(archive_tickets.id) as 'unique_id' , #{select}" if sql_conditions[0].include?('helpdesk_tags.name')
      select
    end

    def archive_sql_conditions
      @index_filter = Helpdesk::Filters::ArchiveTicketFilter.new.deserialize_from_params(export_params)
      sql_conditions = @index_filter.sql_conditions
      if sql_conditions[0].present?
        sql_conditions[0].concat("and #{archive_date_conditions}")
      else
        sql_conditions = [archive_date_conditions]
      end
      @sql_conditions = sql_conditions
    end

    def archive_joins
      @index_filter.get_joins(archive_sql_conditions)
    end

    def archive_date_conditions
      %(archive_tickets.#{export_params[:ticket_state_filter]}
         between '#{export_params[:start_date]}' and '#{export_params[:end_date]}'
        )
    end

    def reorder_contact_company_fields(type)
      export_fields = export_params[:"#{type}_fields"]
      actual_fields = contact_company_fields_order(type)

      export_params[:"#{type}_fields"] = sort_export_fields export_fields, actual_fields
    end

    def email_params
      @email_params ||= {
        user: User.current,
        domain: export_params[:portal_url],
        url: hash_url(export_params[:portal_url]),
        export_params: export_params,
        type: 'ticket'
      }
    end

    def skip_association_preload(association_model)
      export_params[:archived_tickets].present? && DISASSOCIATED_MODELS[:archive_tickets].include?(association_model)
    end

    # build_attachment method is overridden here to support larger export files
    # uploads the file to S3 only after the attachment is saved.
    def build_attachment(file_path)
      file = File.open(file_path, 'r')
      file_name = file_path.split('/').last
      file_size = file.size.to_i
      @export_stats.merge!(size: file_size, md5: Digest::MD5.file(file).hexdigest) if account.launched?(:silkroad_shadow)
      attachment = @data_export.build_attachment(content_file_name: file_name, content_file_size: file_size)
      attachment.upload_to_s3(file) if attachment.save!
      @data_export.file_uploaded!
    end

    def custom_export_logger
      @custom_export_logger ||= CustomLogger.new(Rails.root.join('log', 'export.log'))
    end

    def logging_format(silkroad_data_export)
      "a=#{Account.current.id}, id=#{silkroad_data_export.job_id}, t=#{Time.now.to_i - @data_export.created_at.to_i}, " \
        "s=#{@export_stats[:size]}, n=#{@export_stats[:number_of_records]}, md5=#{@export_stats[:md5]}"
    end
end
