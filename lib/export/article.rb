class Export::Article < Struct.new(:export_params)
  include HasScope
  include Solution::ArticleFilters
  include ExportCsvUtil
  include Export::Util
  include Solution::PathHelper

  FILE_FORMAT = ['csv'].freeze
  DATE_TIME_PARSE = [:created_at, :updated_at, :modified_at].freeze
  BATCH_SIZE = 100
  EXCLUDE_LIST = %w[tags author_name recent_author_name folder_name category_name].freeze

  def perform
    begin
      initialize_params
      set_current_user
      @portal_articles = Account.current.solution_articles.portal_articles(@params[:portal_id], [@lang_id]).preload(export_preload_options)
      @items = apply_article_scopes(@portal_articles)
      data_export_type = 'article'
      create_export data_export_type
      @file_path = generate_file_path("#{@data_export.id}_#{data_export_type}", export_params[:format])
      Sharding.run_on_slave { export_articles }
      if @no_articles
        send_no_article_email
      else
        upload_file(@file_path)
        DataExportMailer.send_email(:article_export, email_params[:user], email_params)
      end
    rescue Exception => e # rubocop:disable RescueException
      NewRelic::Agent.notice_error(e)
      Rails.logger.debug "Error  ::#{e.message}\n#{e.backtrace.join("\n")}"
      @data_export.failure!(e.message + "\n" + e.backtrace.join("\n"))
      DataExportMailer.send_email(:export_failure, email_params[:user], email_params)
    end
  ensure
    # Moving data exports entry to failed status in case of any failures
    if !@data_export.destroyed? && @data_export.status == DataExport::EXPORT_STATUS[:started]
      Rails.logger.error "Article export status at the end of export job :: #{@data_export.status}"
      @data_export.failure!('Export::Failed')
      DataExportMailer.send_email(:export_failure, email_params[:user], email_params)
    end
    schedule_export_cleanup(@data_export, data_export_type) if @data_export.present?
  end

  attr_reader :params

  def export_preload_options
    ::SolutionConstants::EXPORT_PRELOAD_OPTIONS
  end

  def self.enqueue(export_params)
    # Not using the methods in RedisOthers to avoid the include /extend problem
    # class methods vs instance methods issue.
    job_id = ::Articles::Export::ArticlesExport.perform_async(export_params)
    Rails.logger.info "Article Export :: #{job_id}"
  end

  def export_articles
    write_export_file(@file_path) do |file|
      safe_send("#{export_params[:format]}_article_export", file)
    end
  end

  def csv_article_export(file)
    @headers = export_params[:export_fields].keys
    write_csv(file, @headers.collect { |header| export_params[:export_fields][header] })
    @batch_no = 0
    @no_articles = true
    build_export_exclude_list
    @items.find_in_batches(batch_size: BATCH_SIZE) do |rows|
      build_file(rows, file)
    end
  end

  def send_no_article_email
    email_params = { user: User.current, domain: export_params[:portal_url] }
    DataExportMailer.send_email(:no_articles, email_params[:user], email_params)
    @data_export.destroy
  end

  def build_export_exclude_list
    @exclude_list = [:description, :attachments]
    EXCLUDE_LIST.each { |field| @exclude_list << field.to_sym unless @headers.include?(field) }
  end

  def build_file(rows, file)
    @no_articles = false
    Rails.logger.debug "Processing article export batch :: #{@batch_no += 1}"
    rows.each do |row|
      enriched = Solutions::ArticleDecorator.new(row, draft: row.draft, exclude: @exclude_list, language_code: @lang_code, language_metric: true).to_export_hash
      record = []
      data = ''
      begin
        @headers.each do |val|
          data = enriched[val.to_sym]
          record << format_data(val, data)
        end
        write_csv(file, record)
      rescue Exception => e # rubocop:disable RescueException
        Rails.logger.info "Exception in articles export::: Article:: #{row.id}, data:: #{data}, exception:: #{e}"
      end
    end
  end

  def email_params
    @email_params ||= {
      user: User.current,
      domain: export_params[:portal_url],
      url: hash_url(export_params[:portal_url]),
      export_params: export_params,
      type: 'article'
    }
  end

  protected

    def initialize_params
      export_params.symbolize_keys!
      @params = export_params[:filter_params]
      @params.symbolize_keys!
      @lang_id = export_params[:lang_id]
      @lang_code = export_params[:lang_code]
      export_params[:format] = FILE_FORMAT[0] unless FILE_FORMAT.include? export_params[:format]
      reconstruct_params
    end

    def format_data(val, data)
      if data.present? && DATE_TIME_PARSE.include?(val.to_sym)
        data = parse_date(data)
      end
      escape_html(strip_equal(data))
    end
end
