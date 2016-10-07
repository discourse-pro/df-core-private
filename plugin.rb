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
end