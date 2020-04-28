# frozen_string_literal: true

require 'migration/page_language'

RSpec.describe Migration::PageLanguage do
  describe '#migrate_pages' do
    let(:exhibit) { FactoryBot.create(:exhibit) }
    let(:page) { FactoryBot.create(:feature_page, exhibit: exhibit) }
    let(:slug) { FriendlyId::Slug.find(page.id) }

    before do
      # Remove the locale scope (anticipating pre translation state of scope)
      slug.scope = slug.scope.sub(',locale:en', '')
      slug.save
      slug.reload
    end

    it 'sets the scope to the default locale' do
      expect(slug.scope).not_to include(',locale:en')
      subject.run
      slug.reload
      expect(slug.scope).to include ',locale:en'
    end
  end
end
