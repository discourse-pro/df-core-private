# name: df-core-private
# version: 1.1.5
# authors: Dmitrii Fediuk
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
	# require 'categories_controller'
	# 2024-08-26
	# «LoadError: cannot load such file -- categories_controller»: https://github.com/discourse-pro/df-core-private/issues/13
	# load File.expand_path('../../app/controllers/categories_controller.rb', __dir__)
	load File.expand_path(Rails.root + 'app/controllers/categories_controller.rb')
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
				params[:parent_category_id] ? 'categories_with_featured_topics' : 'categories_and_latest_topics'
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
		# 2018-01-12
		# @see CategoryFeaturedTopic.feature_topics_for
		# 1) [Discourse 2.0.0.beta1]
		# «ArgumentError (wrong number of arguments (given 1, expected 0))» /
		# «vendor/bundle/ruby/2.4.0/gems/activerecord-5.1.4/lib/active_record/relation.rb:492:in `delete_all'»
		# https://github.com/discourse-pro/df-core-private/issues/4
		# 2) https://github.com/discourse/discourse/blob/v1.8.0.beta7/app/models/category_featured_topic.rb#L16-L54
		# 3) https://github.com/discourse/discourse/blob/v2.0.0.beta1/app/models/category_featured_topic.rb#L43-L81
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

			# It may seem a bit odd that we are running 2 queries here, when admin
			# can clearly pull out all the topics needed.
			# We do so, so anonymous will ALWAYS get some topics
			# If we only fetched as admin we may have a situation where anon can see
			# no featured topics (all the previous 2x topics are only visible to admins)

			# Add topics, even if they're in secured categories or invisible
			query = TopicQuery.new(Discourse.system_user, query_opts)
			results = query.list_category_topic_ids(c).uniq

			# Add some topics that are visible to everyone:
			anon_query = TopicQuery.new(nil, query_opts.merge(except_topic_ids: [c.topic_id] + results))
			results += anon_query.list_category_topic_ids(c).uniq

			return if results == existing

			CategoryFeaturedTopic.transaction do
				CategoryFeaturedTopic.where(category_id: c.id).delete_all
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