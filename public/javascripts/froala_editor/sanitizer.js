/*jslint browser: true, devel: true */
/*global  Sanitizer */

window.Sanitizer = window.Sanitizer || {};

(function ($) {
  "use strict";

  Sanitizer = {

  	cleanMicrosoftContent: function (html) {
  		html = this.onPasteFromWord(html);
  		html = this.onPasteFromExcel(html);

  		/**
  			* Get only body content to strip the garbage characters outside of the body.
  		**/
  		var bodyContent = html.match(/<body(.*?) ([\w\W]*?)<\/body>/g);
  		html = (bodyContent != null) ? bodyContent[0] : html;
      
  		return html;
  	},

   	onPasteFromWord: function (html) {
      // hack to solve concatenation issue while paste from msWord in Windows OS
      html = html.replace(/[\n]/gi, ' ');

      // Remove comments
      html = html.replace(/<!--[\s\S]*?-->/gi, '');

      // Remove style
      html = html.replace(/<style[^>]*>[\s\S]*?<\/style>/gi, '');

      if (/(class=\"?Mso|style=\"[^\"]*\bmso\-|w:WordDocument)/.test(html))
      {
	      // shapes
	      html = html.replace(/<img(.*?)v:shapes=(.*?)>/gi, '');
	      html = html.replace(/src="file\:\/\/(.*?)"/, 'src=""');

	      // Remove mso classes.
	      html = html.replace(/(\n|\r| class=(")?Mso[a-zA-Z0-9]+(")?)/gi, ' ');

	      // Remove comments.
	      html = html.replace(/<!--[\s\S]*?-->/gi, '');

	      // html = html.replace(/&nbsp;/gi, '');

	      // remove ms word tags
	      html = html.replace(/<o:p(.*?)>([\w\W]*?)<\/o:p>/gi, '$2');

        // To prevent the removing lines.
	      html = html.replace(/\>\s+\</g,'><');

        // Will Remove the wrapped DIV content. For Title content
        html = html.replace(/<div(.*?)><p(.*?)>((?:[\w\W]*?))<\/p><\/div>/g,'<p $1>$3</p>');

			}
				
      return html;
    },

    onPasteFromExcel: function (html) {
      // Set border to table
      if(/(microsoft-com|schemas-microsoft-com:office:excel|content=Excel.Sheet)/.test(html)) {
        html = html.replace(/<table(.*?)border=0/, '<table$1 border=1') 
      }

      return html;
    }

  }
}(window.jQuery));