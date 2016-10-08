# name: df-core-private
# version: 1.1.0
# authors: Dmitry Fedyuk
register_asset 'stylesheets/all.scss'
# 2016-10-07
# https://code.dmitry-fedyuk.com/discourse/my/issues/3
# «Сделать поведение главной темы раздела таким же, как и остальных тем:
# поднимать вверх при обновлении и показывать в списке тем на странице раздела».
# https://github.com/discourse/discourse/blob/v1.7.0.beta5/lib/topic_query.rb#L498-L501
after_initialize do
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
				per_page: SiteSetting.category_featured_topics,
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