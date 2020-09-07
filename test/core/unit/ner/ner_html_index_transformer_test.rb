require_relative '../../test_helper'

# Copy keys to ner_api.yml from stack settings under ner key before running this test

class NERHtmlIndexTransformerTest < ActiveSupport::TestCase

  include ActionView::Helpers::TextHelper

  def test_should_find_right_indexes_in_html
    @text = "Let's meet tomorrow at 3 pm I will be reaching within the next 45 minutes"
    @html = %{<div dir="ltr"> <div>LEt's meet tomorrow at 3 pm</div> <div><br></div> <div>I will be reaching within the next 45 minutes</div> </div>}
    assert_html_indexes
  end

  # Test logic when NER character limit is imposed
  def test_should_find_right_indexes_in_html_for_large_text
    @text = "Ducimus aliquid provident. Soluta et quos. Perferendis saepe inventore animi quo voluptatum tempore. Nihil voluptatem
     autem error adipisci veniam rerum. Fugit veritatis voluptatem eligendi ratione laboriosam repellendus occaecati. Consequatur 
     cupiditate id aliquam quis nobis accusamus iste. Aliquid repellendus illo veniam nisi non qui.12:01:15Rem perferendis at repellat 
     enim vero voluptates est. Adipisci totam repellat praesentium sed voluptatum quis. Quas qui repudiandae ipsa est quos magni excepturi. 
     Et natus perspiciatis nisi. Quia ducimus alias rerum accusamus. Commodi sunt magni.  \n   \n Necessitatibus perferendis repudiandae. 
     Sunt quam id. Sed occaecati hic porro alias. Nisi reiciendis in et cupiditate est ut saepe. Odio consequatur molestias itaque voluptatem omnis. 
     Illum fuga eos dicta molestiae in vel.todaySimilique tenetur voluptatibus ullam. Sit molestiae non laboriosam. Occaecati pariatur inventore veniam velit dolorum. 
     Ut ad distinctio. Delectus facere illum qui quis. Error soluta libero ea sit autem cupiditate aut. Voluptas quidem eos. Explicabo ducimus perspiciatis maiores
      qui vel ut pariatur. Qui in provident. Perspiciatis et praesentium beatae ducimus repellat est accusantium.in an hourMagni odit totam et officiis consequuntur tenetur.
      Vitae natus assumenda temporibus. Reprehenderit consectetur quasi consequuntur quos possimus nihil alias. Sed facilis dicta amet praesentium vel assumenda. Molestiae
      necessitatibus vitae nemo porro facilis aut quo.todayDeserunt voluptatem ducimus. Atque et nemo nesciunt beatae ut ut. Sequi in voluptas nobis aperiam. \n   \n  
      Nulla velit at modi dolores. Molestiae et quo impedit blanditiis consequatur. Ipsam iste perspiciatis deserunt. Minus quis aliquam amet incidunt.Dolores 
      harum velit autem. Molestiae qui itaque voluptatem. Iusto nostrum et doloremque eos. Et rerum voluptatem explicabo perspiciatis unde possimus quas. Ex odit fugit officiis. 
      Omnis nulla placeat qui quo ut. Aut laudantium consectetur expedita quasi. Sapiente quidem consequatur. Non fugit laboriosam ea corporis. Laborum iste eius repellat. 
      Magnam ut consequatur officia laborum voluptatem velit. Temporibus dolore ratione accusamus molestiae blanditiis. Aut accusamus et sunt minus. Molestiae voluptatem et pariatur unde quis. 
      Ipsum deleniti voluptatem animi eum. Iste alias molestias. A soluta quo ut numquam in itaque pariatur. Est placeat aut enim quia. Distinctio ut magnam libero aut. 
      Earum nemo aut doloribus eius dicta blanditiis qui. Expedita eaque sequi quos vel doloribus enim. Recusandae eveniet voluptatum non. Nulla quidem odit sed magnam voluptates. 
      Reprehenderit praesentium voluptate est eos cum. Delectus alias tempore. A unde qui voluptatem omnis odio explicabo. Enim voluptas laborum. Harum magnam excepturi doloremque. 
      Facere dolores vel nihil. Et nisi vel dolores sit. Asperiores inventore dolore explicabo repudiandae voluptatem.12:00 PMOfficia et nam earum distinctio sit non. 
      Laboriosam eum omnis laudantium vel enim corrupti sapiente. Porro et voluptas consequatur laudantium dolores. Debitis doloremque odio. Enim ut modi necessitatibus unde et possimus. 
      Recusandae dolores accusamus dolorem aliquid dolorum rerum.  \n   \n Provident est voluptatibus deleniti labore maiores illo. Iste suscipit dicta aliquid nam voluptas. 
      Dolores incidunt nemo. Quos rerum placeat reiciendis. Rerum animi ipsam. Dolore perspiciatis doloribus provident temporibus vel eaque. Qui sit facere molestiae ea. Qui autem et excepturi. 
      Aliquid soluta mollitia ut. Assumenda sint libero magnam rem nihil. Quidem debitis id vel temporibus alias ad numquam. Quia enim maiores totam illum nihil molestiae. Veritatis dolor eos fuga. 
      Eos rerum sunt earum. Perferendis quos dolorum ratione vero aliquid dolorem. Suscipit omnis voluptatem et sunt ea est. Commodi fuga deserunt nam velit labore perferendis blanditiis. 
      Rem ut vel blanditiis ut quia molestias. Ratione asperiores ducimus aut molestias iusto. Distinctio mollitia voluptatem autem deserunt omnis. Ipsam voluptate in beatae voluptatum exercitationem. 
      Nesciunt excepturi esse unde illum mollitia explicabo. Aut et expedita quam atque reprehenderit eveniet. Illum praesentium eum porro et doloremque. Rerum dolorem aspernatur animi blanditiis omnis 
      at nihil.8pm India TimeEt corrupti eaque enim dignissimos repudiandae. Voluptate commodi cumque corrupti. Et similique repellendus molestiae omnis rerum. Aperiam repellendus ratione a enim quia. 
      Numquam quia esse cum. Magni sapiente laudantium et accusamus ea dolor aliquid. Id voluptatem unde sapiente nobis ut aut."
    @html = simple_format(@text)
    assert_operator @text.length, :>, NERWorker::MAXIMUM_LENGTH
    assert_html_indexes
  end

  private

  def make_ner_request
    req_body = {  text: @text.to_s.first(NERWorker::MAXIMUM_LENGTH) } # Sending only first 3000 characters to api because the api response time is more than 4sec for the string length >3000

    response = RestClient.send("post", NER_API_TOKENS['datetime'], req_body, {"Content-Type"=>"application/json"})
    JSON.parse(response)
  end

  def assert_html_indexes
    @text_indexes = make_ner_request
    @html_indexes = NER::HtmlIndexTransformer.new( :ner_data => @text_indexes, 
        :text => @text, :html => @html).perform 
    @text_indexes["datetimes"].zip(@html_indexes["datetimes"]).each do |text_ner, html_ner|
      text_substr = @text[text_ner["value"]["start"]..(text_ner["value"]["end"] - 1)]
      html_substr = @html[html_ner["value"]["start"]..html_ner["value"]["end"]]
      assert_equal text_substr, html_substr
      assert_equal text_ner["value"].except("start", "end"), html_ner["value"].except("start", "end")
    end
  end
end