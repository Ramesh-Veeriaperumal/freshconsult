/*jslint browser: true */
/*global FreshWidget, $H, WidgetConfig:true */
var WidgetConfig = function () {};

(function ($) {
	"use strict";
	
	WidgetConfig = function (urls, account_url) {
		this.urls = urls;
		this.account_url = account_url;
		this.asset_url = this.urls.http;
		
		this.initialize();
	};
	
	WidgetConfig.prototype = {
		constructor: WidgetConfig,
		
		IGNORE: ['authenticity_token'],
		IN_PX: ['offset', 'formHeight'],
		PLACEHOLDERS: ['offset', 'formHeight', 'buttonText'],
		
		initialize: function () {
			this.setDefaults();
			this.bindHandlers();
			this.initWidget();
			
			this.activeForm.trigger("change");
		},
		initWidget: function () {			
			FreshWidget.init("", {
				"buttonText": "Support",
				"buttonBg": "#000000",
				"alignment": "4",
				"offset": "30%",
				"assetUrl": this.urls.http
			});
		},
		setDefaults: function () {
			this.formHash = $H();
			this.formHash.set('queryString', '');
			
			this.activeForm = $("#fw-tab-content form:visible");
		},
		bindHandlers: function () {
			var $this = this;
			$("#fw-tab-content form").change(function (ev) { $this.onConfigChange(); });
			this.activeForm.find('[name="buttonText"]').keyup(function (ev) { $this.onConfigChange(); });
			$('#TabColor').bind('colorpicked', function (ev) { $this.onConfigChange(); });
			$("#fw-tabs a").on("change.widget_config", function (ev) {
				$this.activeForm = $("#fw-tab-content form:visible").trigger("change");
			});
			
			$('#httpsHttp').on('change.widget_config', function (ev) {
				$this.asset_url = (this.checked) ? $this.urls.https : $this.urls.http;
			});
			
		},
		onConfigChange: function () {
			this.setDefaults();
			this.buildHash();
			FreshWidget.update(this.formHash.toObject());
			
			this.updateCode();
			this.highlightCode();
		},
		updateCode: function () {
			this.formHash.set('url', this.account_url);
			$("#popupCode").val(this.getPopupCode());
			$("#embeddedCode").val(this.getEmbeddedCode());
		},
		getPopupCode: function () {
			return '<' + 'script type="text/javascript" src="' + this.asset_url + '/freshwidget.js"></' + 'script>\n' +
				'<' + 'script type="text/javascript">\n' +
				'\tFreshWidget.init("", ' + this.formHash.toJSON() + ' );\n' +
				'<' + '/script>';
		},
		getEmbeddedCode: function () {
			var jsonOfHash = $.parseJSON(this.formHash.toJSON());
			return '<' + 'script type="text/javascript" src="' + this.asset_url + '/freshwidget.js"></' + 'script>\n' +
				'<' + 'style type="text/css" media="screen, projection">\n' +
				'\t@import url(' + this.asset_url + '/freshwidget.css); \n' +
				'</' + 'style> \n' +
				'<' + 'iframe class="freshwidget-embedded-form" id="freshwidget-embedded-form" src="' + this.account_url +
				'/widgets/feedback_widget/new?' + jsonOfHash.queryString + '" scrolling="no" height="' + jsonOfHash.formHeight +
				'" width="100%" frameborder="0" >\n' +
				'<' + '/iframe>';
		},
		buildHash: function () {
			var formArray = this.activeForm.serializeArray(), $this = this;
			this.formHash.set('backgroundImage', '');	//Setting a default empty value
			
			$.each(formArray, function (index, item) {
				var $item = $this.activeForm.find('[name=' + item.name + ']');
				$this.updateHashFor(item, $item);
			});
		},
		updateHashFor: function (item, $dom) {
			
			if (this.IGNORE.indexOf(item.name) === -1) {
				item = this.processItem(item, $dom);
				if (item.value !== '') {
					
					if ($dom.data('setQueryString')) {
						this.formHash.set("queryString", this.formHash.get("queryString") + '&' + $dom.serialize());
					}
					
					if (!$dom.data('skipOptions')) {
						this.formHash.set(item.name, item.value);
					}
				}
			}
		},
		processItem: function (item, $dom) {
			if (this.PLACEHOLDERS.indexOf(item.name) !== -1 && $.trim(item.value) === '') {
				item.value = $dom.attr('placeholder');
			}
			
			if (this.IN_PX.indexOf(item.name) !== -1 && $.trim(item.value) !== '') {
				item.value += 'px';
			}
			
			//Special Handling for buttonBg - which sets ButtonColor also by contrasting
			if (item.name === 'buttonBg') {
				this.formHash.set('buttonColor', $.fn.mColorPicker.textColor($dom.css("border-right-color")));
			}
			
			return item;
		},
		highlightCode: function () {
			if (!$('[name="buttonText"]').is(":focus") && !$("#TabColor").is(":focus")) {
				$("#popupCode").effect("highlight", { color: "#F8F8C3" }, 600);
			}
		}
	};
}(window.jQuery));