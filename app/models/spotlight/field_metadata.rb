# frozen_string_literal: true

module Spotlight
  ##
  # Expose Solr index metadata about fields
  class FieldMetadata
    FACET_LIMIT = 20

    include Spotlight::SearchHelper

    attr_reader :exhibit, :repository, :blacklight_config, :current_ability

    def initialize(exhibit, repository, blacklight_config, current_ability)
      @exhibit = exhibit
      @repository = repository
      @blacklight_config = blacklight_config
      @current_ability = current_ability
    end

    def field(key)
      {
        document_count: document_counts.fetch(field_name(key), 0),
        value_count: terms.fetch(field_name(key), []).length
      }
    end

    def search_params
      search_service.search_builder.merge(rows: 0, 'facet.limit' => FACET_LIMIT + 1)
    end

    private

    def field_name(key)
      if blacklight_config.facet_fields[key]
        blacklight_config.facet_fields[key].field
      else
        key
      end
    end

    def solr_response
      @solr_response ||= repository.search(search_params.merge('facet.query' => facet_fields.map { |_key, fields| "#{fields.field}:[* TO *]" },
                                                               'rows' => 0,
                                                               'facet' => true))
    end

    # This gets the number of *documents* with a field
    def document_counts
      @document_count ||= solr_response.facet_queries.each_with_object({}) do |(k, v), h|
        h[k.split(/:/).first] = v
      end
    end

    def terms
      @terms ||= solr_response.aggregations.each_with_object({}) do |(facet_name, facet), h|
        h[facet_name] = facet.items.map(&:label)
      end
    end

    def facet_fields
      blacklight_config.facet_fields.reject { |_k, v| v.pivot || v.query }
    end

    alias current_exhibit exhibit
  end
end
