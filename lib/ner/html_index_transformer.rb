class NER::HtmlIndexTransformer

  attr_accessor :ner_data, :text, :html, :text_indexes, :ner_root

  def initialize(args = {})
    args.each do |k,v|
      instance_variable_set("@#{k}", v)
    end
    @ner_root = ner_data.keys.first
    @text_indexes = ner_data[ner_root]
  end

  def perform
    offset = 0
    html_untouched = html
    html_ner_indexes = []
    text_indexes.each_with_index do |current_ner_data, index|
      begin
        if index > 0 && duplicate_sub_string?(current_ner_data, text_indexes[index-1])
          html_ner_indexes << transform_current_value(current_ner_data, html_ner_indexes.last["value"].slice("start", "end"))
          next
        end
        sub_string = text[current_ner_data["value"]["start"]..(current_ner_data["value"]["end"] - 1)]
        start_index = html.to_s.index(sub_string)
        next unless start_index
        end_index = start_index + sub_string.length 
        html_sub_string = html_untouched[(offset + start_index)..(offset + end_index - 1)]
        if sub_string == html_sub_string
          html_ner_indexes << transform_current_value(current_ner_data, {"start" => offset + start_index, "end" => offset + end_index})
          @html = html[(end_index+1)..-1]
          offset += (end_index + 1)
        end
      rescue => e
        Rails.logger.error("Error while transforming ner text to html indexes: \n#{e} \n#{e.backtrace.join("\n")} \n#{current_ner_data}")
        NewRelic::Agent.notice_error(e)
      end
    end
    { ner_root => html_ner_indexes }
  end

  private

  def duplicate_sub_string?(current, previous)
    current['value'].slice('start', 'end') == previous['value'].slice('start', 'end')
  end

  def transform_current_value(current_ner_data,indices)
    {'value' => current_ner_data['value'].merge(indices)}
  end
end