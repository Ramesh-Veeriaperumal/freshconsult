if (typeof RTOOLBAR == 'undefined') var RTOOLBAR = {};

RTOOLBAR['small'] = {
	html:
	{
		title: RLANG.html,
		func: 'toggle',
		separator: true
	},	
	bold:
	{
		title: RLANG.bold,
		exec: 'bold'
	}, 
	italic: 
	{
		title: RLANG.italic,
		exec: 'italic',
		separator: true		
	},
	insertunorderedlist:
	{
		title: '&bull; ' + RLANG.unorderedlist,
		exec: 'insertunorderedlist'
	},
	link:
	{ 
		title: RLANG.link, 
		func: 'show', 				
		dropdown: 
		{
			link: 	{name: 'link', title: RLANG.link_insert, func: 'showLink'},
			unlink: {exec: 'unlink', name: 'unlink', title: RLANG.unlink}
		}															
	},
	fontcolor:
	{
		title: RLANG.fontcolor, 
		func: 'show'
	},
	backcolor:
	{
		title: RLANG.backcolor, 
		func: 'show',
		separator: true		
	}
};