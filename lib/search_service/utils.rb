module SearchService
  class Utils
    def self.construct_payload(types, template_name, es_params)
      {
        search_term: es_params[:search_term].to_s,
        account_id: es_params[:account_id],
        documents: types,
        context: template_name,
        params: es_params.except(:search_term, :account_id, :size, :from, :sort_by, :sort_direction),
        size: es_params[:size],
        from: es_params[:from] || 0,
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
      end.compact

      result_set
     end
  end
end
