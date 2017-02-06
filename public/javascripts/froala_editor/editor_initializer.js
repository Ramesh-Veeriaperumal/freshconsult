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
				// Extra added FONT tag to allow
				htmlAllowedTags: ['a', 'abbr', 'address', 'area', 'article', 'aside', 'audio', 'b', 'base', 'bdi', 'bdo', 'blockquote', 'br', 'button', 'canvas', 'caption', 'cite', 'code', 'col', 'colgroup', 'datalist', 'dd', 'del', 'details', 'dfn', 'dialog', 'div', 'dl', 'dt', 'em', 'embed', 'fieldset', 'figcaption', 'figure', 'footer', 'form', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'header', 'hgroup', 'hr', 'i', 'iframe', 'img', 'input', 'ins', 'kbd', 'keygen', 'label', 'legend', 'li', 'link', 'main', 'map', 'mark', 'menu', 'menuitem', 'meter', 'nav', 'noscript', 'object', 'ol', 'optgroup', 'option', 'output', 'p', 'param', 'pre', 'progress', 'queue', 'rp', 'rt', 'ruby', 's', 'samp', 'script', 'style', 'section', 'select', 'small', 'source', 'span', 'strike', 'strong', 'sub', 'summary', 'sup', 'table', 'tbody', 'td', 'textarea', 'tfoot', 'th', 'thead', 'time', 'title', 'tr', 'track', 'u', 'ul', 'var', 'video', 'wbr', 'font'],
				pluginsEnabled: ['fullscreen', 'paragraphFormat', 'paragraphStyle', 'fontSize', 'fontFamily', 'colors', 'align', 'lists', 'quote', 'image', 'imageManager', 'video', 'table', 'link', 'codeView', 'lineBreaker', 'codeInsert','pasteHandler', 'codeBeautifier', 'commonEvents', 'pasteToggler'], //
				toolbarButtons: ['paragraphFormat', 'fontFamily', 'fontSize', 'color', 'bold', 'italic', 'underline', 'strikethrough', 'paragraphStyle', '|',  'align', '|', 'formatOL', 'formatUL', 'outdent', 'indent', '|', 'insertLink', 'insertTable', 'insertImage', 'insertVideo',  'codeInsert', 'insertHR', '|', 'plainText', 'defaultFormatting', 'originalFormatting', '|', 'html', 'fullscreen'],
				toolbarButtonsSM: null,
				toolbarButtonsMD: null,
				toolbarButtonsXS: null,
				paragraphFormat: {
			      N: 'Normal',
			      H1: 'Heading 1',
			      H2: 'Heading 2',
			      H3: 'Heading 3',
			      H4: 'Heading 4',
			      BLOCKQUOTE: 'Quote',
			      PRE: 'Code'
			    },
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
				imageDefaultWidth: 0,
				sanitizeType: "solution"
			})

		default:
	}
}