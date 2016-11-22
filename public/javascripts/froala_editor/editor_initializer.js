(function ($) {

  'use strict';
	
	$.FroalaEditor.DEFAULTS.key = 'Qg1Ti1LXd2URVJh1DWXG==';

	// By default the editor will use the font_awesome. Changing to our icons
	$.FroalaEditor.DefineIconTemplate('fd_design_icon', '<i class="ficon-[NAME]"></i>');
	$.FroalaEditor.ICON_DEFAULT_TEMPLATE = 'fd_design_icon';

	// By default it will access only the iframe and embed tag. This will allow all tags
	$.FE.VIDEO_EMBED_REGEX = /<\/?([a-z][a-z0-9]*)\b[^>]*>/gi;

})(jQuery);

function invokeEditor(element_id,type,attr) {
	var element_id = "#" + element_id;
	switch(type){
		case 'solution':
			jQuery(element_id).froalaEditor({
				pasteDeniedAttrs:['class', 'id', 'style'],
				htmlRemoveTags: ['script', 'style', 'base'],
				pluginsEnabled: ['fullscreen', 'paragraphFormat', 'paragraphStyle', 'fontSize', 'fontFamily', 'colors', 'align', 'lists', 'image', 'imageManager', 'video', 'table', 'link', 'codeView', 'lineBreaker', 'codeInsert','pasteHandler', 'codeBeautifier', 'commonEvents', 'pasteToggler'], //
				toolbarButtons: ['paragraphFormat', 'fontFamily', 'fontSize', 'color', 'bold', 'italic', 'underline', 'strikethrough', 'paragraphStyle', '|',  'align', '|', 'formatOL', 'formatUL', 'outdent', 'indent', '|', 'insertLink', 'insertTable', 'insertImage', 'insertVideo',  'codeInsert', 'insertHR', '|', 'plainText', 'defaultFormatting', 'originalFormatting', '|', 'html', 'fullscreen'],
				toolbarButtonsSM: null,
				toolbarButtonsMD: null,
				toolbarButtonsXS: null,
				fontFamily: {
					"'Andale Mono', AndaleMono, monospace" : 'Andale Mono',
					'Arial,Helvetica,sans-serif': 'Arial',
					"'Arial Black',Gadget,sans-serif" : 'Arial Black',
					"'Book Antiqua', Georgia, serif" : 'Book Antiqua',
					"'Comic Sans MS', cursive, sans-serif" : 'Comic Sans MS',
					"'Courier New', Courier, monospace" : 'Courier New',
					'Georgia,serif': 'Georgia',
					'Helvetica,sans-serif' : 'Helvetica',
					'Helvetica Neue' : 'Helvetica Neue',
					'Impact,Charcoal,sans-serif': 'Impact',
					'Symbol': 'Symbol',
					'Tahoma,Geneva,sans-serif': 'Tahoma',
					"'Trebuchet MS', Helvetica, sans-serif" : 'Trebuchet MS',
					"'Times New Roman',Times,serif": 'Times New Roman',
					'Terminal, monospace' : 'Terminal',
					'Verdana,Geneva,sans-serif': 'Verdana',
					'Windings': 'Windings'
				},
				tableStyles: {
					'fr-dashed-borders': 'Dashed Borders',
  					'fr-alternate-rows': 'Alternate Rows',
  					'fr-no-borders': 'No Borders'
				},
				fontSize: ['8', '9', '10', '11', '12', '13', '14', '16', '18', '24', '30', '36', '48', '60', '72', '96'],
				toolbarSticky: false,
				toolbarContainer: "#sticky_redactor_toolbar",
				tabSpaces: 4,
				charCounterCount: false,
				lineBreakerTags: ['table', 'hr', 'form', 'dl', 'span.fr-video', 'pre'],
				linkInsertButtons:['linkBack', '|'],
				linkEditButtons: ['linkOpen', 'linkEdit', 'linkRemove'],
				imageUploadURL: '/solutions_uploaded_images',
				imageUploadMethod: 'POST',
				imageUploadParam: 'image[uploaded_data]',
				imageUploadParams: {
					'_uniquekey': new Date().getTime(),
					'authenticity_token': jQuery('[name="csrf-token"]').attr('content')
				},
				imageManagerLoadURL: '/solutions_uploaded_images',
				imageManagerLoadMethod: 'GET',
				sanitizeType: "solution"
			})

		default:
	}
}