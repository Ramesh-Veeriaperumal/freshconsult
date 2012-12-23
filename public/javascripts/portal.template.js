var FD = FD || {};
FD.PortalTemplate = (function($){
	var resetFormSubmit = function(form){ form.onsubmit = function(){ return false } },
			rjssubmit = function(elm){				
				var form = $(elm.form),
					url = form.action,
					data = form.serialize(),
					data = data+'&'+elm.name+'='+$(elm).attr('originalValue');

					if(!form.valid()) {
						enableElement(elm)
						$('input:blank').focus();
						return;
					}
				$.post( form[0].action, data, undefined, "script" );
			},
			disableElement = function(elm) {
				$(elm).attr({
					'originalValue' : elm.value,
					'disabled'      : true,
					'value'         : $(elm).data().disableWith || elm.value
				});
			},
			enableElement = function(elm) {
				$(elm).attr({
					'disabled'      : false,
					'value'         : $(elm).attr('originalValue')
				});
			},
			populate_codemirror = function(elm){
				$(elm.data("codeRefresh")).val('')
				$(elm.data("codeRefresh")).codemirror('save');
			},
			prerequitions = function(elm){
				populate_codemirror($(elm))
				resetFormSubmit(elm.form);
				// disableElement(elm);
				rjssubmit(elm);
			};
	return {
		save : function(elm,evt){
			prerequitions(elm);
			return false;
		}
	}
})(jQuery)