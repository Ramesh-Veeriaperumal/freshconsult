(function ($) {

  'use strict';

	$.FroalaEditor.DEFAULTS.key = 'QB4G4C3A14hC7D6E6C5D2E3C2C6A7A5cODOe1HLEBFZOTGHW==';

	// By default the editor will use the font_awesome. Changing to our icons
	$.FroalaEditor.DefineIconTemplate('fd_design_icon', '<i class="ficon-[NAME]"></i>');
	$.FroalaEditor.ICON_DEFAULT_TEMPLATE = 'fd_design_icon';

	// By default it will access only the iframe and embed tag. This will allow all tags
	$.FE.VIDEO_EMBED_REGEX = /<\/?([a-z][a-z0-9]*)\b[^>]*>/gi;

})(jQuery);

function invokeEditor(element_id,type,attr) {
	var element_id = "#" + element_id;
	var froala_common_options = {
		pasteDeniedAttrs:['class', 'id', 'style'],
		htmlRemoveTags: ['script', 'style', 'base'],
		// Extra added FONT tag to allow
		htmlAllowedTags: ['a', 'abbr', 'address', 'area', 'article', 'aside', 'audio', 'b', 'base', 'bdi', 'bdo', 'blockquote', 'br', 'button', 'canvas', 'caption', 'cite', 'code', 'col', 'colgroup', 'datalist', 'dd', 'del', 'details', 'dfn', 'dialog', 'div', 'dl', 'dt', 'em', 'embed', 'fieldset', 'figcaption', 'figure', 'footer', 'form', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'header', 'hgroup', 'hr', 'i', 'iframe', 'img', 'input', 'ins', 'kbd', 'keygen', 'label', 'legend', 'li', 'link', 'main', 'map', 'mark', 'menu', 'menuitem', 'meter', 'nav', 'noscript', 'object', 'ol', 'optgroup', 'option', 'output', 'p', 'param', 'pre', 'progress', 'queue', 'rp', 'rt', 'ruby', 's', 'samp', 'script', 'style', 'section', 'select', 'small', 'source', 'span', 'strike', 'strong', 'sub', 'summary', 'sup', 'table', 'tbody', 'td', 'textarea', 'tfoot', 'th', 'thead', 'time', 'title', 'tr', 'track', 'u', 'ul', 'var', 'video', 'wbr', 'font'],
		htmlAllowedAttrs: ['accept', 'accept-charset', 'accesskey', 'action', 'align', 'allowfullscreen', 'allowtransparency', 'alt', 'async', 'autocomplete', 'autofocus', 'autoplay', 'autosave', 'background', 'bgcolor', 'border', 'charset', 'cellpadding', 'cellspacing', 'checked', 'cite', 'class', 'color', 'cols', 'colspan', 'content', 'contenteditable', 'contextmenu', 'controls', 'coords', 'data-.*', 'datetime', 'default', 'defer', 'dir', 'dirname', 'disabled', 'download', 'draggable', 'dropzone', 'enctype', 'for', 'form', 'formaction', 'frameborder', 'headers', 'height', 'hidden', 'high', 'href', 'hreflang', 'http-equiv', 'icon', 'id', 'ismap', 'itemprop', 'keytype', 'kind', 'label', 'lang', 'language', 'list', 'loop', 'low', 'max', 'maxlength', 'media', 'method', 'min', 'mozallowfullscreen', 'multiple', 'muted', 'name', 'novalidate', 'open', 'optimum', 'pattern', 'ping', 'placeholder', 'playsinline', 'poster', 'preload', 'pubdate', 'radiogroup', 'readonly', 'rel', 'required', 'reversed', 'rows', 'rowspan', 'sandbox', 'scope', 'scoped', 'scrolling', 'seamless', 'selected', 'shape', 'size', 'sizes', 'span', 'src', 'srcdoc', 'srclang', 'srcset', 'start', 'step', 'summary', 'spellcheck', 'style', 'tabindex', 'target', 'title', 'type', 'translate', 'usemap', 'value', 'valign', 'webkitallowfullscreen', 'width', 'wrap'],
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
		toolbarContainer: "#sticky_redactor_toolbar",
		tabSpaces: 4,
		charCounterCount: false,
		lineBreakerTags: ['table', 'hr', 'form', 'dl', 'span.fr-video', 'pre'],
		linkInsertButtons:['linkBack', '|'],
		linkEditButtons: ['linkOpen', 'linkEdit', 'linkRemove'],
		imageUploadMethod: 'POST',
		imageUploadParam: 'image[uploaded_data]',
		videoInsertButtons: ['videoByURL', 'videoEmbed'],
		imageEditButtons: ['imageReplace', 'imageAlign', 'imageRemove', 'imageLink', 'linkOpen', 'linkEdit', 'linkRemove', '-', 'imageDisplay', 'imageStyle', 'imageAlt', 'imageSize'],
		colorsHEXInput: false,
		imageUploadParams: {
			'_uniquekey': new Date().getTime(),
			'authenticity_token': jQuery('[name="csrf-token"]').attr('content')
		},
		imageManagerLoadMethod: 'GET',
		imageDefaultWidth: 0,
		// locale
		language: I18n.locale
	}

	// common froala forum options
	var invokeForumEditor = function(allowHtml) {
		var allowHtml = allowHtml || false;

		froala_forum_options = {
			pluginsEnabled: ['fullscreen', 'paragraphFormat', 'paragraphStyle', 'fontSize', 'fontFamily', 'colors', 'align', 'lists', 'quote', 'image', 'imageManager', 'video', 'table', 'link', 'codeView', 'lineBreaker', 'codeInsert','pasteHandler', 'codeBeautifier', 'commonEvents'],
			toolbarButtons: ['bold', 'italic', 'underline', 'color', 'strikethrough', 'paragraphStyle', '|',  'align', '|', 'formatOL', 'formatUL', 'outdent', 'indent', '|', 'insertLink', 'insertTable', 'insertImage', 'insertVideo',  'codeInsert', 'insertHR', '|', 'fullscreen'],
			imageUploadURL: '/forums_uploaded_images',
			imageManagerLoadURL: '/forums_uploaded_images',
			sanitizeType: "forum",
		}


		if (allowHtml) {
			froala_forum_options.toolbarButtons.splice(froala_forum_options.toolbarButtons.length-1 , 0, "html") // push before fullscreen;
		}

		jQuery(element_id).froalaEditor(jQuery.extend({}, froala_common_options, froala_forum_options))

		// enabling image uploaded event for inline images
		jQuery(element_id).on('froalaEditor.image.uploaded', function (e, editor, data) {
			var currentForm = editor.$el.parents('form');
			var inlineAttachmentScoper = editor.$oel.attr('name').replace(/\[.*\]/g, "");
			var inlineAttachmentInput = jQuery('<input type="hidden">').attr({
				name: inlineAttachmentScoper + '[inline_attachment_ids][]',
				value: JSON.parse(data).fileid
			});
			currentForm.append(inlineAttachmentInput);
		});
	};


	switch(type) {
		case 'solution':
		  froala_solution_options = {
				pluginsEnabled: ['fullscreen', 'paragraphFormat', 'paragraphStyle', 'fontSize', 'fontFamily', 'colors', 'align', 'lists', 'quote', 'image', 'imageManager', 'video', 'table', 'link', 'codeView', 'lineBreaker', 'codeInsert','pasteHandler', 'codeBeautifier', 'commonEvents', 'pasteToggler'],
				toolbarButtons: ['paragraphFormat', 'fontFamily', 'fontSize', 'color', 'bold', 'italic', 'underline', 'strikethrough', 'paragraphStyle', '|',  'align', '|', 'formatOL', 'formatUL', 'outdent', 'indent', '|', 'insertLink', 'insertTable', 'insertImage', 'insertVideo',  'codeInsert', 'insertHR', '|', 'clearFormatting', 'defaultFormatting', 'originalFormatting', '|', 'html', 'fullscreen'],
				imageUploadURL: '/solutions_uploaded_images',
				imageManagerLoadURL: '/solutions_uploaded_images',
				sanitizeType: "solution",
				toolbarSticky: false
			}
			jQuery(element_id).froalaEditor(jQuery.extend({}, froala_common_options, froala_solution_options))
			break;

		case 'forum':
			invokeForumEditor();
			break;
		
		case 'topic':
			invokeForumEditor(true);
			break;

		default:
	}
}
