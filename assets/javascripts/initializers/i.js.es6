import {decorateCooked} from 'discourse/lib/plugin-api';
export default {name: 'df-core-private', after: 'inject-objects', initialize: function(container) {
	decorateCooked(container, function($post) {
		// Удаляем ненужные параграфы, которые редактор вставляет
		// при наличии внутри элементов списка блоков кода.
		/** @type {jQuery} HTMLDivElement[] */
		$('.cooked li > pre').prevAll('p').each(function() {
			var $p = $(this);
			var $children = $p.children();
			!$children.length ? $p.remove() : $children.unwrap();
		});
	});
}};