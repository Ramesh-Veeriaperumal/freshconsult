module Admin::PortalHelper

	def multiple_feature_radio_btn(group, features, options={})
		content_tag('div', { :class => "#{group} multiple_radio", :id => "#{group}" }) do
			op = ""
			selected = applicable_feature(features)
			features.each do |feature, label|
				op << content_tag(:span, multi_radio_btn_for(feature, group, label, selected), options)
			end
			op.html_safe
		end
	end

	def feature_radio_button(features, options={})
		content_tag('div', :class => "multiple_radio") do
			op = ""
			group = (features.keys - [:default]).first
			selected = applicable_feature(features)
			features.each do |feature, label|
				op << content_tag(:span, radio_btn_for(feature, group, label, selected), options)
			end
			op.html_safe
		end
	end

	def applicable_feature(features)
		features.keys.reverse.each do |feature|
			return feature if feature != :default && current_account.features_included?(feature)
		end
		:default
	end

	def multi_radio_btn_for(feature, group, label, selected)
		op = []
		id = feature.eql?(:default) ? "feature_#{group}" : "account_features_#{feature}"
		op << radio_button("feature_#{group}", "select",nil, multi_radio_btn_options(feature, group, id, selected))
		op << hidden_field_tag("account", feature.eql?(selected) ? 1 : 0, multi_hidden_options(feature)) unless feature.eql?(:default)
		op << label_for(label, id)
		op.join('').html_safe
	end

	def radio_btn_for(feature, group, label, selected)
		op = []
		op << radio_button("feature", "select", feature.eql?(:default) ? 0 : 1, radio_btn_options(feature, group, selected))
		op << label_for(label, "account_features_#{feature}_#{group}")
		op.join('').html_safe
	end

	def multi_radio_btn_options(feature, group, id, selected)
		{ 
			'data-name' => "account[features][#{feature}]",
			'data-group' => group,
			:id => id,
			:checked => feature.eql?(selected)
		}
	end

	def multi_hidden_options(feature)
		{
			:id => "account_features_#{feature}",
			:name => "account[features][#{feature}]"
		}
	end

	def radio_btn_options(feature, group, selected)
		{
			:id => "account_features_#{feature}_#{group}",
			:name => "account[features][#{group}]",
			:checked => feature.eql?(selected)
		}
	end

	def label_for(label, id)
		unless label.is_a?(Array)
			content_tag(:label, label, :for => id)
		else
			(content_tag(:label, label[0], :for => id) + content_tag(:div, label[1], :class => "muted ml17 mb10")).html_safe
		end
	end
end