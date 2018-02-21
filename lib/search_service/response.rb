module SearchService
  class Response
    attr_accessor :records, :total_entries, :error, :response_object

    delegate :total_time, :starttransfer_time, :appconnect_time, :pretransfer_time, :connect_time, :namelookup_time,
             :redirect_time, :headers, :code, :timed_out?, :request, :body, to: :response_object

    def initialize(response)
      @response_object = response
      @records = JSON.parse(response.body) rescue {}
      @total_entries = @records['total'].to_i
      @error = @records['error']
    end

    attr_reader :total_entries, :records, :error

    def records_with_ar(model_and_assoc, account_id, paginate_params)
      record_hash = {}
      search_results = @records

      (search_results['results'].presence || {}).group_by { |item| item['document'] }.each do |type, items|
        record_hash[type] = if items.empty?
                              []
                            else
                              model_and_assoc[type][:model]
                                .constantize
                                .where(account_id: account_id, id: items.map { |h| h['id'] })
                                .preload(model_and_assoc[type][:associations])
                                .compact
                            end
      end

      result_set = search_results['results'].map do |item|
        detected = record_hash[item['document']].detect do |record|
          record.id.to_s == item['id'].to_s
        end

        item['highlight'].keys.each do |field|
          detected.safe_send("highlight_#{field}=", [*item['highlight'][field]].join(' ... ')) if detected.respond_to?("highlight_#{field}=")
        end if item['highlight'].present?

        detected
      end.compact

      Search::V2::PaginationWrapper.new(result_set, paginate_params.merge(total_entries: total_entries))
    end
  end
end
