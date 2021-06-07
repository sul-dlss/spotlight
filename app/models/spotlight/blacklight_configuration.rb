# frozen_string_literal: true

require 'blacklight/open_struct_with_hash_access'

module Spotlight
  ##
  # Exhibit-specific blacklight configuration model
  # rubocop:disable Metrics/ClassLength
  class BlacklightConfiguration < ActiveRecord::Base
    has_paper_trail

    belongs_to :exhibit, touch: true, optional: true
    serialize :facet_fields, Hash
    serialize :index_fields, Hash
    serialize :search_fields, Hash
    serialize :sort_fields, Hash
    serialize :default_solr_params, Hash
    serialize :show, Hash
    serialize :index, Hash
    serialize :per_page, Array
    serialize :document_index_view_types, Array

    include Spotlight::BlacklightConfigurationDefaults

    delegate :document_model, to: :default_blacklight_config

    # get rid of empty values
    before_validation do |model|
      model.index_fields&.each do |_k, v|
        v[:enabled] ||= v.any? { |_k1, v1| v1.present? }

        default_blacklight_config.view.keys.each do |view|
          v[view] &&= value_to_boolean(v[view])
        end

        v[:show] &&= value_to_boolean(v[:show])
        v.reject! { |_k, v1| v1.blank? && v1 != false }
      end

      model.facet_fields&.each do |_k, v|
        v[:show] &&= value_to_boolean(v[:show])
        v[:show] ||= true if v[:show].nil?
        v.reject! { |_k, v1| v1.blank? && v1 != false }
      end

      model.search_fields&.each do |k, v|
        v[:enabled] &&= value_to_boolean(v[:enabled])
        v[:enabled] ||= true if v[:enabled].nil?
        v[:label] = default_blacklight_config.search_fields[k][:label] if default_blacklight_config.search_fields[k] && v[:label].blank?
        v.reject! { |_k, v1| v1.blank? && v1 != false }
      end

      model.sort_fields&.each do |k, v|
        v[:enabled] &&= value_to_boolean(v[:enabled])
        v[:enabled] ||= true if v[:enabled].nil?
        v[:label] = default_blacklight_config.sort_fields[k][:label] if default_blacklight_config.sort_fields[k] && v[:label].blank?
        v.reject! { |_k, v1| v1.blank? && v1 != false }
      end

      model.per_page&.reject!(&:blank?)
      model.document_index_view_types&.reject!(&:blank?)
    end

    ##
    # Serialize this configuration to a Blacklight::Configuration object
    # appropriate to the current view. If a value isn't set in this record,
    # it will use the configuration set upstream (in default_blacklight_config)
    # @param [String] view the configuration may be different depending on the index view selected
    # rubocop:disable Metrics/MethodLength, Metrics/PerceivedComplexity, Metrics/CyclomaticComplexity, Metrics/AbcSize
    def blacklight_config
      @blacklight_config ||= begin
        # Create a new config based on the defaults
        config = default_blacklight_config.inheritable_copy(self.class)

        config.current_exhibit = exhibit

        config.document_presenter_class = lambda do |context|
          if context.action_name == 'index'
            config.index.document_presenter_class
          else
            config.show.document_presenter_class
          end
        end

        config.show.merge! show unless show.blank?
        config.index.merge! index unless index.blank?
        config.index.respond_to[:iiif_json] = true

        config.index.thumbnail_field ||= Spotlight::Engine.config.thumbnail_field

        config.add_results_collection_tool 'curator_actions', if: :render_curator_actions?

        unless config.curator_actions
          config.curator_actions ||= Blacklight::NestedOpenStructWithHashAccess.new(Blacklight::Configuration::ToolConfig)
          config.curator_actions.save_search!
          config.curator_actions.bulk_actions!
        end

        unless config.bulk_actions
          config.bulk_actions ||= Blacklight::NestedOpenStructWithHashAccess.new(Blacklight::Configuration::ToolConfig)

          config.bulk_actions.change_visibility!
          config.bulk_actions.add_tags!
          config.bulk_actions.remove_tags!
        end

        config.default_solr_params = config.default_solr_params.merge(default_solr_params)

        config.default_per_page = default_per_page if default_per_page

        config.view.embed!
        config.view.embed.partials ||= ['openseadragon']
        config.view.embed.if = false
        config.view.embed.locals ||= { osd_container_class: '' }

        # Add any custom fields
        config.index_fields.merge! custom_index_fields(config)
        config.index_fields.reject! { |_k, v| v.if == false }

        # Update with customizations
        config.index_fields.each do |k, v|
          v.original = v.dup
          if index_fields[k]
            v.merge! index_fields[k].symbolize_keys
          elsif v.custom_field
            set_custom_field_defaults(v)
          else
            set_index_field_defaults(v)
          end

          v.immutable = Blacklight::OpenStructWithHashAccess.new(v.immutable)
          v.merge! v.immutable.to_h.symbolize_keys

          v.if = :field_enabled? unless v.if == false

          v.normalize! config
          v.validate!
        end

        config.show_fields.reject! { |_k, v| v.if == false }

        config.show_fields.reject { |k, _v| config.index_fields[k] }.each do |k, v|
          v.original = v.dup
          config.index_fields[k] = v

          if index_fields[k]
            v.merge! index_fields[k].symbolize_keys
          else
            set_show_field_defaults(v)
          end

          v.immutable = Blacklight::OpenStructWithHashAccess.new(v.immutable)
          v.merge! v.immutable.to_h.symbolize_keys

          v.if = :field_enabled? unless v.if == false

          v.normalize! config
          v.validate!
        end

        ##
        # Sort after the show fields have also been added
        config.index_fields = Hash[config.index_fields.sort_by { |k, _v| field_weight(index_fields, k) }]

        config.show_fields = config.index_fields

        config.search_fields.merge! custom_search_fields(config)
        if search_fields.present?
          config.search_fields = Hash[config.search_fields.sort_by { |k, _v| field_weight(search_fields, k) }]

          config.search_fields.each do |k, v|
            v.original = v.dup
            v.if = :field_enabled? unless v.if == false
            next if search_fields[k].blank?

            v.merge! search_fields[k].symbolize_keys
            v.normalize! config
            v.validate!
          end
        end

        if sort_fields.present?
          config.sort_fields = Hash[config.sort_fields.sort_by { |k, _v| field_weight(sort_fields, k) }]

          config.sort_fields.each do |k, v|
            v.original = v.dup
            v.if = :field_enabled? unless v.if == false
            next if sort_fields[k].blank?

            v.merge! sort_fields[k].symbolize_keys
            v.normalize! config
            v.validate!
          end
        end

        config.facet_fields.merge! custom_facet_fields
        if facet_fields.present?
          config.facet_fields = Hash[config.facet_fields.sort_by { |k, _v| field_weight(facet_fields, k) }]

          config.facet_fields.each do |k, v|
            v.original = v.dup unless v.custom_field
            next if facet_fields[k].blank?

            v.merge! facet_fields[k].symbolize_keys
            v.enabled = v.show
            v.if = :field_enabled? unless v.if == false
            v.normalize! config
            v.validate!
          end
        end

        config.per_page = (config.per_page & per_page) if per_page.present?

        if document_index_view_types.present?
          config.view.each do |k, v|
            v.original = v.dup
            v.key = k
            v.if = :enabled_in_spotlight_view_type_configuration? unless v.if == false
          end
        end

        if config.search_fields.blank?
          config.navbar.partials[:saved_searches].if = false if config.navbar.partials.key? :saved_searches
          config.navbar.partials[:search_history].if = false if config.navbar.partials.key? :search_history
        end

        config
      end
    end
    # rubocop:enable Metrics/MethodLength, Metrics/PerceivedComplexity, Metrics/CyclomaticComplexity

    def custom_index_fields(blacklight_config)
      Hash[exhibit.custom_fields.reject(&:new_record?).map do |custom_field|
        original_config = blacklight_config.index_fields[custom_field.field] || {}
        field = Blacklight::Configuration::IndexField.new original_config.merge(
          custom_field.configuration.merge(
            key: custom_field.field, field: custom_field.solr_field, custom_field: true
          )
        )
        [custom_field.field, field]
      end]
    end

    def custom_facet_fields
      Hash[exhibit.custom_fields.facetable.reject(&:new_record?).map do |x|
        field = Blacklight::Configuration::FacetField.new x.configuration.merge(
          key: x.field, field: x.solr_field, show: false, custom_field: true
        )
        field.if = :field_enabled?
        field.enabled = false
        field.limit = true
        [x.field, field]
      end]
    end

    def custom_search_fields(blacklight_config)
      Hash[exhibit.custom_search_fields.reject(&:new_record?).map do |custom_field|
        original_config = blacklight_config.search_fields[custom_field.field] || {}
        field = Blacklight::Configuration::SearchField.new original_config.merge(
          custom_field.configuration.merge(
            key: custom_field.slug, solr_parameters: { qf: custom_field.field }, custom_field: true
          )
        )
        [custom_field.slug, field]
      end]
    end

    ##
    # Get the "upstream" blacklight configuration to use
    def default_blacklight_config
      @default_blacklight_config ||= begin
        config = Spotlight::Engine.blacklight_config.deep_copy
        add_exhibit_specific_fields(config)
        config
      end
    end

    # Parse params checkbox arrays into simple arrays.
    # A group of checkboxes on a form returns values like this:
    #   {"list"=>"1", "gallery"=>"1", "map"=>"0"}
    # where, "list" and "gallery" are selected and "map" is not. This function
    # digests that hash into a list of selected values. e.g.:
    #   ["list", "gallery"]
    def document_index_view_types=(hash_or_array)
      if hash_or_array.is_a? Hash
        super(hash_or_array.select { |_, checked| checked == '1' }.keys)
      else
        super(hash_or_array)
      end
    end

    # @return [OpenStructWithHashAccess] keys are view types; value is 1 if enabled
    # A group of checkboxes on a form needs values like this:
    #   {"list"=>"1", "gallery"=>"1", "map"=>"0"}
    # where, "list" and "gallery" are selected and "map" is not. This function
    # takes ["list", "gallery"] and turns it into the above.
    def document_index_view_types_selected_hash
      selected_view_types = document_index_view_types
      avail_view_types = default_blacklight_config.view.to_h.reject { |_k, v| v.if == false }.keys
      Blacklight::OpenStructWithHashAccess.new.tap do |s|
        avail_view_types.each do |k|
          s[k] = selected_view_types.include?(k.to_s)
        end
      end
    end

    protected

    def add_exhibit_specific_fields(config)
      add_exhibit_tags_fields(config)
      add_uploaded_resource_fields(config)
      add_autocomplete_field(config)
    end

    def add_exhibit_tags_fields(config)
      # rubocop:disable Style/GuardClause
      unless config.show_fields.include? :exhibit_tags
        config.add_show_field :exhibit_tags, field: config.document_model.solr_field_for_tagger(exhibit),
                                             link_to_facet: true,
                                             separator_options: { words_connector: nil, two_words_connector: nil, last_word_connector: nil }
      end

      unless config.facet_fields.include? :exhibit_tags
        config.add_facet_field :exhibit_tags, field: config.document_model.solr_field_for_tagger(exhibit), limit: true
      end
      # rubocop:enable Style/GuardClause
    end

    def add_uploaded_resource_fields(config)
      exhibit.uploaded_resource_fields.each do |f|
        add_uploaded_resource_field(config, f)
      end
    end

    def add_uploaded_resource_field(config, f)
      key = Array(f.solr_field || f.field_name).first.to_s

      return if config.index_fields.any? { |_k, v| v.field == key }

      options = f.blacklight_options || {}
      options[:label] = f.label if f.label

      config.add_index_field key, options
    end

    def add_autocomplete_field(config)
      return unless Spotlight::Engine.config.autocomplete_search_field && !config.search_fields[Spotlight::Engine.config.autocomplete_search_field]

      config.add_search_field(Spotlight::Engine.config.autocomplete_search_field) do |field|
        field.include_in_simple_select = false
        field.solr_parameters = Spotlight::Engine.config.default_autocomplete_params.deep_dup
        field.solr_parameters[:fl] ||= default_autocomplete_field_list(config)
      end
    end

    def default_autocomplete_field_list(config)
      [
        config.document_model.unique_key,
        config.view_config(:show).title_field,
        config.index.thumbnail_field || Spotlight::Engine.config.thumbnail_field,
        Spotlight::Engine.config.iiif_manifest_field
      ].flatten.join(' ')
    end

    # rubocop:disable Naming/AccessorMethodName
    def set_index_field_defaults(field)
      return if index_fields.present?

      views = default_blacklight_config.view.keys | %i[show enabled]
      field.merge!((views - field.keys).index_with { |v| !title_only_by_default?(v) })
    end

    # Check to see whether config.view.foobar.title_only_by_default is available
    def title_only_by_default?(view)
      return false if %i[show enabled].include?(view)

      title_only = default_blacklight_config.view.send(:[], view)&.title_only_by_default
      title_only.nil? ? false : title_only
    end

    def set_show_field_defaults(field)
      return if index_fields.present?

      views = default_blacklight_config.view.keys
      field.merge! views.index_with { |_v| false }
      field.enabled = true
      field.show = true
    end

    def set_custom_field_defaults(field)
      field.show = true if field.show.nil?
      field.enabled = true if field.enabled.nil?
    end
    # rubocop:enable Naming/AccessorMethodName

    # @return [Integer] the weight (sort order) for this field
    def field_weight(fields, index)
      if fields[index] && fields[index][:weight]
        fields[index][:weight].to_i
      else
        100 + (fields.keys.index(index) || fields.keys.length)
      end
    end

    def value_to_boolean(v)
      ActiveModel::Type::Boolean.new.cast v
    end
  end
end
