import {decorateCooked} from 'discourse/lib/plugin-api';
export default {name: 'df-core-private', after: 'inject-objects', initialize: function(c) {
	decorateCooked(c, onDecorateCooked);
}};
/**
 * Удаляем ненужные параграфы, которые редактор вставляет
 * при наличии внутри элементов списка блоков кода.
 *
 * 2015-08-06
 * 1) decorateCooked вызывает своих подписчиков для каждого сообщения отдельно.
 * 2) $post содержит не только сообщение, но и элементы управления.
 * Чтобы применить свои селекторы только к сообщению,
 * используйте родительский селектор .cooked, например:
 * const $tables = $('.cooked > table', $post);
 * @used-by decorateCooked
 * @link https://github.com/discourse/discourse/blob/v1.4.0.beta7/app/assets/javascripts/discourse/lib/plugin-api.js.es6#L5
 * @param {jQuery} HTMLDivElement $post
 * @returns void
 */
const onDecorateCooked = function($post) {
	/**
	 * @link http://api.jquery.com/prevall/
	 * .prevAll() ввыбирает все предшествующие элементы-братья данного элемента
	 * (опционально отфильтровывая их).
	 */
	/** @type {jQuery} HTMLDivElement[] */
	$('.cooked li > pre', $post).prevAll('p').each(function() {
		/** @type {jQuery} HTMLParagraphElement */
		const $p = $(this);
		/** @type {jQuery} HTMLElement[] */
		const $children = $p.children();
		!$children.length ? $p.remove() : $children.unwrap();
	});
};