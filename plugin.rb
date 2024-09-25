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
	# 2024-08-26
	# 1) «LoadError: cannot load such file -- categories_controller»: https://github.com/discourse-pro/df-core-private/issues/13
	# 2) The previous code was:
	#		require 'categories_controller'
	# https://github.com/discourse-pro/df-core-private/blob/1.1.5/plugin.rb#L16
	# 3) Another working solution:
	# 		load File.expand_path(Rails.root + 'app/controllers/category_featured_topic.rb')
	# https://github.com/discourse-pro/df-core-private/blob/2024-08-26/plugin.rb#L21
	require_dependency 'categories_controller'
	CategoriesController.class_eval do
		# 2018-01-10
		# 1) «undefined method `before_filter' for CategoriesController:Class»
		# https://github.com/discourse-pro/df-core-private/issues/3
		# 2) «`before_filter` has been deprecated in Rails 5.0 and removed in 5.1»
		# https://stackoverflow.com/a/45015788
		before_action :dfSetCategoryStyle
		def categories_and_top
			categories_and_topics(:top)
		end
		# 2024-09-25
		# 1) "Order topics on the home page by the number of views by default":
		# https://github.com/discourse-pro/df-core-private/issues/21
		# @override
		# @see https://github.com/discourse/discourse/blob/v3.4.0.beta1/app/controllers/categories_controller.rb#L31-L102
		def index
			discourse_expires_in 1.minute
			@description = SiteSetting.site_description
			parent_category =
			if params[:parent_category_id].present?
				Category.find_by_slug(params[:parent_category_id]) ||
				Category.find_by(id: params[:parent_category_id].to_i)
			elsif params[:category_slug_path_with_id].present?
				Category.find_by_slug_path_with_id(params[:category_slug_path_with_id])
			end
			include_subcategories =
				SiteSetting.desktop_category_page_style == "subcategories_with_featured_topics" ||
				params[:include_subcategories] == "true"
			category_options = {
				include_subcategories: include_subcategories,
				include_topics: include_topics(parent_category),
				is_homepage: current_homepage == "categories",
				page: params[:page],
				parent_category_id: parent_category&.id,
				tag: params[:tag],
			}
			@category_list = CategoryList.new(guardian, category_options)
			if category_options[:is_homepage] && SiteSetting.short_site_description.present?
				@title = "#{SiteSetting.title} - #{SiteSetting.short_site_description}"
			elsif !category_options[:is_homepage]
				@title = "#{I18n.t("js.filters.categories.title")} - #{SiteSetting.title}"
			end
			respond_to do |format|
				format.html do
					store_preloaded(
						@category_list.preload_key,
						MultiJson.dump(CategoryListSerializer.new(@category_list, scope: guardian)),
					)
					style = SiteSetting.desktop_category_page_style
					topic_options = { per_page: CategoriesController.topics_per_page, no_definitions: true }
					if style == "categories_and_latest_topics_created_date"
						topic_options[:order] = "created"
						@topic_list = TopicQuery.new(current_user, topic_options).list_latest
						@topic_list.more_topics_url = url_for(public_send("latest_path", sort: :created))
					elsif style == "categories_and_latest_topics"
						@topic_list = TopicQuery.new(current_user, topic_options).list_latest
						@topic_list.more_topics_url = url_for(public_send("latest_path"))
					elsif style == "categories_and_top_topics"
						@topic_list =
						TopicQuery.new(current_user, topic_options).list_top_for(
							SiteSetting.top_page_default_timeframe.to_sym,
						)
						@topic_list.more_topics_url = url_for(public_send("top_path"))
					end
					if @topic_list.present? && @topic_list.topics.present?
						store_preloaded(
							@topic_list.preload_key,
							MultiJson.dump(TopicListSerializer.new(@topic_list, scope: guardian)),
						)
					end
					render
				end
				format.json { render_serialized(@category_list, CategoryListSerializer) }
			end
		end
		private
		# 2024-09-25
		# 1) "Order topics on the home page by the number of views by default":
		# https://github.com/discourse-pro/df-core-private/issues/21
		# @override
		# @see https://github.com/discourse/discourse/blob/v3.4.0.beta1/app/controllers/categories_controller.rb#L519-L553
		def categories_and_topics(topics_filter)
			discourse_expires_in 1.minute
			cfg = {per_page: CategoriesController.topics_per_page, no_definitions: true}
			cfg.merge!(build_topic_list_options)
			r = CategoryAndTopicLists.new
			r.category_list = CategoryList.new(guardian, {
				include_topics: false,
				is_homepage: 'categories' == current_homepage,
				page: params[:page],
				parent_category_id: params[:parent_category_id]
			})
			if topics_filter == :latest
				if 'categories_and_latest_topics_created_date' == SiteSetting.desktop_category_page_style
					cfg[:order] = 'created'
				end
				r.topic_list = TopicQuery.new(current_user, cfg).list_latest
				r.topic_list.more_topics_url = url_for(
					public_send('latest_path', sort: cfg[:order] == 'created' ? :created : nil)
				)
			elsif topics_filter == :top
				cfg[:order] = 'views'
				r.topic_list = TopicQuery.new(current_user, cfg).list_latest
				r.topic_list.more_topics_url = url_for(public_send('latest_path'))
			end
			render_serialized(r, CategoryAndTopicListsSerializer, root: false)
		end
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
	# 2024-08-26
	# 1) «LoadError: cannot load such file -- category_featured_topic»: https://github.com/discourse-pro/df-core-private/issues/14
	# 2) The previous code was:
	#		require 'category_featured_topic'
	# https://github.com/discourse-pro/df-core-private/blob/1.1.5/plugin.rb#L38
	# 3) Another working solution:
	# 		load File.expand_path(Rails.root + 'app/controllers/category_featured_topic.rb')
	# https://github.com/discourse-pro/df-core-private/blob/2024-08-26/plugin.rb#L21
	require_dependency 'category_featured_topic'
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