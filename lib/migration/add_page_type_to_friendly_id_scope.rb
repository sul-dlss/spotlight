# frozen_string_literal: true

module Migration
  ##
  # Different types of pages are accessed through their
  # own controllers so they can have the same slug. We've
  # added the page type to the scope, and this updates existing
  # page slugs to include page type for consistency
  class AddPageTypeToFriendlyIdScope
    def self.run
      new.migrate_slugs
    end

    def migrate_slugs
      slugs.find_each do |slug|
        next if /type:\w+/ =~ slug.scope

        slug.scope = new_scope(slug)
        slug.save
      end
    end

    def new_scope(slug)
      (slug.scope.split(',') << new_scope_part(slug)).sort.join(',')
    end

    def new_scope_part(slug)
      "type:#{slug.sluggable.type}"
    end

    def slugs
      FriendlyId::Slug.where(sluggable_type: 'Spotlight::Page')
    end
  end
end
