/* Load this script using conditional IE comments if you need to support IE 7 and IE 6. */

window.onload = function() {
	function addIcon(el, entity) {
		var html = el.innerHTML;
		el.innerHTML = '<span style="font-family: \'widget-icons\'">' + entity + '</span>' + html;
	}
	var icons = {
			'icon-user' : '&#xf007;',
			'icon-question-sign' : '&#xf059;',
			'icon-paper-clip' : '&#xf0c6;',
			'icon-search' : '&#xe007;',
			'icon-camera' : '&#xf030;',
			'icon-email' : '&#xe000;'
		},
		els = document.getElementsByTagName('*'),
		i, attr, html, c, el;
	for (i = 0; ; i += 1) {
		el = els[i];
		if(!el) {
			break;
		}
		attr = el.getAttribute('data-icon');
		if (attr) {
			addIcon(el, attr);
		}
		c = el.className;
		c = c.match(/icon-[^\s'"]+/);
		if (c && icons[c[0]]) {
			addIcon(el, icons[c[0]]);
		}
	}
};