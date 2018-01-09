# name: df-core-private
# version: 1.1.1
# authors: Dmitry Fedyuk
register_asset 'stylesheets/all.scss'
# 2016-10-07
# https://code.dmitry-fedyuk.com/discourse/my/issues/3
# «Сделать поведение главной темы раздела таким же, как и остальных тем:
# поднимать вверх при обновлении и показывать в списке тем на странице раздела».
# https://github.com/discourse/discourse/blob/v1.7.0.beta5/lib/topic_query.rb#L498-L501
after_initialize do
	# 2016-12-18
	if '15432' === SiteSetting.port
		SiteSetting.port = '900'
	end
	# 2016-12-21
	require 'categories_controller'
	CategoriesController.class_eval do
		# 2018-01-10
		# 1) «undefined method `before_filter' for CategoriesController:Class»
		# https://github.com/discourse-pro/df-core-private/issues/3
		# 2) «`before_filter` has been deprecated in Rails 5.0 and removed in 5.1»
		# https://stackoverflow.com/a/45015788
		before_action :dfSetCategoryStyle
		private
		def dfSetCategoryStyle
			SiteSetting.desktop_category_page_style =
				params[:parent_category_id] \
				? 'categories_with_featured_topics' : 'categories_and_latest_topics'
		end
	end
	require_dependency 'topic_query'
	TopicQuery.class_eval do
		alias_method :core__default_results, :default_results
		def default_results(options={})
			options[:no_definitions] = false
			core__default_results options
		end
	end
	require 'category_featured_topic'
	CategoryFeaturedTopic.class_eval do
		def self.feature_topics_for(c, existing=nil)
			return if c.blank?

			query_opts = {
				# 2017-03-07
				# Раньше тут стояло: per_page: SiteSetting.category_featured_topics
				# но 2017-03-01 эта опция была удалена:
				# https://github.com/discourse/discourse/commit/26201660#diff-aeb865119
				per_page: c.num_featured_topics,
				except_topic_ids: [],
				visible: true,
				no_definitions: false
			}

			# Add topics, even if they're in secured categories:
			query = TopicQuery.new(CategoryFeaturedTopic.fake_admin, query_opts)
			results = query.list_category_topic_ids(c).uniq

			# Add some topics that are visible to everyone:
			anon_query = TopicQuery.new(nil, query_opts.merge({except_topic_ids: [] + results}))
			results += anon_query.list_category_topic_ids(c).uniq

			return if results == existing

			CategoryFeaturedTopic.transaction do
				CategoryFeaturedTopic.delete_all(category_id: c.id)
				if results
					results.each_with_index do |topic_id, idx|
						begin
							c.category_featured_topics.create(topic_id: topic_id, rank: idx)
						rescue PG::UniqueViolation
							# If another process features this topic, just ignore it
						end
					end
				end
			end
		end
	end
end