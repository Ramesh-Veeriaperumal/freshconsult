/*!
 * FD Plugin for froala_editor
 */

(function (factory) {
    if (typeof define === 'function' && define.amd) {
        // AMD. Register as an anonymous module.
        define(['jquery'], factory);
    } else if (typeof module === 'object' && module.exports) {
        // Node/CommonJS
        module.exports = function( root, jQuery ) {
            if ( jQuery === undefined ) {
                // require('jQuery') returns a factory that requires window to
                // build a jQuery instance, we normalize how we use modules
                // that require this pattern but the window provided is a noop
                // if it's defined (how jquery works)
                if ( typeof window !== 'undefined' ) {
                    jQuery = require('jquery');
                }
                else {
                    jQuery = require('jquery')(root);
                }
            }
            factory(jQuery);
            return jQuery;
        };
    } else {
        // Browser globals
        factory(jQuery);
    }
}(function ($) {

  'use strict';
	
	$.extend($.FroalaEditor.POPUP_TEMPLATES, {
	  'codeInsert.popup': '[_CUSTOM_LAYER_]'
	});

	$.FE.PLUGINS.codeInsert = function (editor) {
	  var codeEditor_lang = {
			html : 'Html',
			css  : 'Css',
			js   : 'JavaScript',
			sass : 'Sass',
			xml  : 'Xml',
			ruby : 'Ruby',
			php  : 'PHP',
			java : 'Java',
			csharp :'C#',
			cpp  : 'C++',
			objc : 'Obj C',
			perl : 'Perl',
			python :'Python',
			vbnet: 'VB',
			sql  : 'SQL',
			text : 'Generic Language'
		};

		var preEle = "";

	  	function _init() {
	  		initPopup();
	  		observeCodeSnippet();
	  	}

	  // Create custom popup.
		function initPopup () {
			if (!$('.code_popup').get(0)) {
				var template = '<form id="InsertCodeForm" class="insert_code" data-overlay-event=false >' +
						'<label for="insert_text_area" class="text_area_label font-small">Enter code snippet and select language</label>' +
						'<div class="insert_code_dropdown pull-right mb5">' +
						'<div class="vertical-alignment font-small m6">Language : </div>' + buildLangSelector() + 
						'</div>' +
						'<textarea id="insert_text_area" style="width: 99%; height: 250px;"></textarea>' +
						'<span class="code_note font-small">Note: Code highlighting will be applied on articles published on your portal.</span>' +
					'</form>' +
					'<div class="fr_modal_footer">' +
						'<a href="javascript:void(null);" class="btn hide pull-left" id="code_delete_btn" style="color: #000;"> Delete </a>' +
						'<div class="btns_box">' +
							'<a href="javascript:void(null);" class="btn" id="btn_modal_close"> Cancel </a>  ' +
							'<input type="button" class="btn btn-primary" id="insert_code_btn" value="Save" />' +
						'</div>' + 
					'</div>';

			    // Load popup template.
		    var popup_template = '<div class="code_popup fr-overlay" id="code_popup" style="display: none"></div>' +
     				'<div class="fr-modal code_popup fr-insert-code" style="display: none"> <div class="fr-modal-wrapper">' +
      				'<div id="fr_modal_header " class="fr_modal_header fr-modal-title"> <div class="fr-modal-title-line"><h4> Code Snippet </h4><i id="fr_modal_close" class="fr_modal_close fr-modal-close"></i></div></div>' +
      					template + 
      				'</div></div>';

		    	$('body').append(popup_template);
		    }

		    $('#insert_code_btn').off().on('click', function(){
		    	if(!preEle) {
		    		var html = createCodeWrapper();
	    			editor.selection.restore();
			      	editor.html.insert(html);
			      	editor.undo.saveStep();
		    	} else {
		    		var html = updateCodeWrapper(preEle);
		    		preEle.html(html);
		    	}

		    	observeCodeSnippet();
		    	hidePopup();
		    });

		    $('#btn_modal_close, #fr_modal_close').off().on('click',function(){
		    	hidePopup();
		    });

		    $('#code_delete_btn').off().on('click', function(e){
		    	editor.selection.restore();
		    	preEle.remove();
		    	editor.undo.saveStep();
		    	hidePopup();
		    });
		}

		// cre
		function buildLangSelector(){
			var selectOption ='<select id="insertCode_selector" name="highlight-brush-type" data-minimum-results-for-search="100" class="select2 input-medium">'

			$.each(codeEditor_lang,function(key,val){
					selectOption += '<option value="'+ key +'">'+ val +'</option>'
			});

			selectOption += '</select>'; 
			return selectOption;
		}

		function createCodeWrapper(){
			var data = $('#insert_text_area').val(),
					lines = data.split(/\r|\r\n|\n/),
					codeBrush = $('#insertCode_selector').val(),
					codeClass = '';

			// The line of code is greater than 10 
			if(lines.length > 10){
				codeClass = 'code-large';	
			}	

			// Replace tab space to double space
			data = data.replace(/\t/g, '  ');

			// Create block element to insert the code snippet
			var tmp_div = $('<div />') 
			tmp_div.append($('<pre />')
				.attr('rel', 'highlighter')
				.attr('data-code-brush', codeBrush)
				.attr('contenteditable', false)
				.addClass(codeClass)
				.text(data))
				.append($('<p><br/></p>'));

	  	return tmp_div.html();
		}

		function updateCodeWrapper (preElement) {
			var data = $('#insert_text_area').val(),
				lines = data.split(/\r|\r\n|\n/),
				codeBrush = $('#insertCode_selector').val(),
				codeClass = '';

			if(lines.length > 10){
				codeClass = 'code-large';	
			}	

			data = data.replace(/\t/g, '  ');

			preElement.attr('data-code-brush', codeBrush)
				.removeClass('code-large')
				.data('codeBrush', codeBrush)
				.addClass(codeClass)
				.text(data)

			return preElement.html();
		}

		function codeOnEdit(e) {
			preEle = $(e.currentTarget)
			var htmlText = $(e.currentTarget).html()
								.replace(/<br>/g,"\n")
								.replace(/&lt;/g,'<')
								.replace(/&gt;/g,'>')
								.replace(new RegExp("&nbsp;", 'g')," ");

			$('#insert_text_area').val(htmlText);
			$("#code_delete_btn").removeClass('hide');

			showPopup();

			$("#insertCode_selector").val(preEle.data('codeBrush')).trigger("change.select2");
		}	

		function observeCodeSnippet() {
			editor.$el.find('pre').each(function(i, el) {
				$(el).attr('contenteditable',false);
			})

			$(document).off(".editor").on('click.code_insert', ".fr-view [rel='highlighter']", codeOnEdit);
		}

		// Show the modal
		function showPopup () {
			editor.selection.save();
			$(".code_popup").show();
			$(".code_popup #insert_text_area").focus();
			$('body').css('overflow', 'hidden');
			$("#insertCode_selector").val($("#insertCode_selector option:first").val());
		}

		// Hide the modal.
		function hidePopup () {
			preEle = "";
			$('#insert_text_area').val('');
			$('#insertCode_selector').val('').trigger('change.select2');
			$(".code_popup").hide();
			$('body').css('overflow', '');
			$('#code_delete_btn').addClass('hide');
		}

    return {
    	_init: _init,
    	showPopup: showPopup
    }
	}

	$.FE.DefineIcon('codeInsert', { NAME: 'code-snippet' });
	$.FE.RegisterCommand('codeInsert', {
		title: 'Code Insert',
		undo: false,
		focus: false,
		callback: function () {
			this.codeInsert.showPopup();
		},
		plugin: 'codeInsert'
	})

}));