reversePaging = function(url, containerId, total, options) {
	var default_options = {
		itemSelector 		: '.pagedElement',
		showDefault			: 3,
		perPage				: 5,
		bgColor				: '#FFFFFF',
		lineColor			: '#AAAAAA',
		txtColor			: '#000000',
		txtElement			: 'conversation',
		txtElementPlural	: 'conversations',
		txtMore				: 'more'
	}

	for (var opt in default_options) {
		options[opt] = options[opt] || default_options[opt];
	}

	var tmplPages = '<div class="oldconvMsg hide">'+
						'<div></div>'+
						'<div><span class="msg">' +
								'<span class="count">5</span> ' + 
								'<span class="element_type">more conversations</span> ' +
							'</span></div>'+
						'<div class="below"></div>'+
					'</div>'

	var qryItems = '#' + containerId + ' ' + options.itemSelector;
	var container = jQuery('#' + containerId);

	var currentSize = jQuery(qryItems).length;
	console.log(qryItems);
	console.log(currentSize);
	if (currentSize > options.showDefault) {
		console.log('Greater than showdefault');
		itemsToHide = options.showDefault - jQuery(qryItems).length;
		console.log('To Slice');
		console.log(currentSize - options['showDefault'] - 1);
		jQuery(qryItems).slice(0,(currentSize - options.showDefault)).addClass('hide');

		//Constructing the Old Elements Divider element

		if (currentSize - options.showDefault < total) {
			var oldconvMsg = jQuery(tmplPages);
			container.prepend(oldconvMsg);
			oldconvMsg.removeClass('hide');

			oldconvMsg.data('next-page',2);
			oldconvMsg.data('page-url',url);

			console.log('Total : ' + total + ', currentSize: ' + currentSize + ', showDefault: ' + options.showDefault);
			jQuery('#' + containerId + ' .oldconvMsg .msg .count').text(total - options.showDefault);

			oldconvMsg.bind('click',function(ev) {
				jQuery(qryItems).removeClass('hide');
				currentSize = jQuery(qryItems).length;
				if (currentSize < total) {

					jQuery('#' + containerId + ' .oldconvMsg').addClass('loading-center');
					console.log('next-page:'+jQuery('#' + containerId + ' .oldconvMsg').data('next-page'));
					jQuery.ajax({
						url: url+oldconvMsg.data('next-page'),
						success: function (data, textStatus, jqXHR) {
							jQuery('#' + containerId + ' .oldconvMsg').after(data);
							
							jQuery('#' + containerId + ' .oldconvMsg').removeClass('loading-center');
							currentSize = jQuery(qryItems).length;
							console.log('currentSize : ' + currentSize);
							console.log('total : ' + total);

							if (total - currentSize > 0) {
								jQuery('#' + containerId + ' .oldconvMsg .msg .count').text(total - currentSize);
								jQuery('#' + containerId + ' .oldconvMsg').data('next-page',jQuery('#' + containerId + ' .oldconvMsg').data('next-page') + 1);
							} else {
								console.log('Hiding');
								jQuery('#' + containerId + ' .oldconvMsg').hide();
							}
						}
					});
				} else {
					jQuery('#' + containerId + ' .oldconvMsg').hide();
				}
			});
		} 


	}
}