module SearchService
  class Utils
    def self.construct_payload(types, template_name, es_params)
      per_page = es_params[:size].to_i <= 0 ? Search::Utils::MAX_PER_PAGE : es_params[:size].to_i
      {
        search_term: es_params[:search_term].to_s,
        documents: types,
        context: template_name,
        params: es_params.except(:search_term, :account_id, :size, :from, :sort_by, :sort_direction),
        per_page: per_page,
        page: (es_params[:from].to_i/per_page) + 1 ,
        sort_by: es_params[:sort_by],
        sort_direction:  es_params[:sort_direction]
      }.to_json
    end

    def self.load_records(search_results, model_and_assoc, account_id)
      records = {}

      (search_results['results'].presence || {}).group_by { |item| item['document'] }.each do |type, items|
        records[type] = if items.empty?
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
        detected = records[item['document']].detect do |record|
          record.id.to_s == item['id'].to_s
        end

        item['highlight'].keys.each do |field|
          detected.send("highlight_#{field}=", [*item['highlight'][field]].join(' ... ')) if detected.respond_to?("highlight_#{field}=")
        end if item['highlight'].present?

        detected
      end

      result_set
     end
  end
end
