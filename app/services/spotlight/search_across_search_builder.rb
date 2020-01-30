# frozen_string_literal: true

module Spotlight
  # Search builder for getting search results across exhibits
  class SearchAcrossSearchBuilder < Blacklight::SearchBuilder
    include Blacklight::Solr::SearchBuilderBehavior

    self.default_processor_chain += [:filter_public_documents_in_accessible_exhibits]

    def filter_public_documents_in_accessible_exhibits(solr_params)
      fq = Array.wrap(solr_params[:fq])

      if accessible_documents_query.blank?
        solr_params[:fq] = 'id:does-not-exist'
      else
        solr_params[:fq] = fq.append(accessible_documents_query) unless fq.include?(accessible_documents_query)
        solr_params[:"f.#{exhibit_slug_field}.facet.matches"] = Regexp.union(accessible_exhibit_slugs.map(&:slug))
      end

      solr_params
    end

    private

    def exhibit_slug_field
      Spotlight::SolrDocument.exhibit_slug_field
    end

    def accessible_exhibit_slugs
      @accessible_exhibit_slugs ||= Spotlight::Exhibit.accessible_by(current_ability).select(:id, :slug)
    end

    def accessible_documents_query
      accessible_exhibit_slugs.collect do |exhibit|
        filter = []
        filter << "#{exhibit_slug_field}:#{exhibit.slug}"
        filter << "#{blacklight_config.document_model.visibility_field(exhibit)}:true" unless current_ability&.can?(:curate, exhibit)

        "(#{filter.join(' AND ')})"
      end.join(' OR ')
    end

    def current_ability
      (scope&.context || {})[:current_ability]
    end
  end
end
