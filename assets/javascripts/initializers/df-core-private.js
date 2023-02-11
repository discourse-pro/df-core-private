import CategoriesController from 'discourse/controllers/discovery/categories';
import CategoriesRoute from 'discourse/routes/discovery-categories';
import {withPluginApi} from 'discourse/lib/plugin-api';
import computed from 'ember-addons/ember-computed-decorators';
export default {name: 'df-core-private', initialize() {withPluginApi('0.1', api => {
	api.decorateCooked(onDecorateCooked);
	// 2016-12-21 https://guides.emberjs.com/v2.4.0/object-model/reopening-classes-and-instances
	CategoriesController.reopen({
		@computed('model.parentCategory')
		categoryPageStyle(parentCategory) {
			this.siteSettings.desktop_category_page_style =
				parentCategory ? 'categories_with_featured_topics' : 'categories_and_latest_topics'
			;
			return this._super(parentCategory);
		}
	});
	CategoriesRoute.reopen({
		model() {
			this.siteSettings.desktop_category_page_style =
				this.get('model.parentCategory') ? 'categories_with_featured_topics' : 'categories_and_latest_topics'
			;
			return this._super();
		}
	});
});}};
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
 * @param {jQuery} $post HTMLDivElement
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
		/** @type {jQuery} HTMLParagraphElement */ const $p = $(this);
		/** @type {jQuery} HTMLElement[] */ const $c = $p.children();
		!$c.length ? $p.remove() : $c.unwrap();
	});
};