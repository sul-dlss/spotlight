# frozen_string_literal: true

describe 'Link to Search Block', type: :feature, js: true do
  let(:exhibit) { FactoryBot.create(:exhibit) }
  let(:exhibit_curator) { FactoryBot.create(:exhibit_curator, exhibit: exhibit) }

  let!(:feature_page) { FactoryBot.create(:feature_page, exhibit: exhibit) }
  let!(:search1) { FactoryBot.create(:published_search, exhibit: exhibit, title: 'Title1', published: true) }
  let!(:search2) { FactoryBot.create(:published_search, exhibit: exhibit, title: 'Title2', published: true) }

  before do
    login_as exhibit_curator

    visit spotlight.edit_exhibit_feature_page_path(exhibit, feature_page)
    add_widget 'link_to_search'
  end

  it 'allows a curator to select from existing browse categories' do
    check 'Include item counts?'

    fill_in_prefetched_typeahead_field with: 'Title1', wait_for: '[data-type="link_to_search"] [data-browse-fetched]'

    within(:css, '.card') do
      uncheck 'Display?'
    end

    fill_in_prefetched_typeahead_field with: 'Title2', wait_for: '[data-type="link_to_search"] [data-browse-fetched]'

    save_page

    # Documents should exist
    expect(page).not_to have_css('.category-title', text: search1.title)
    expect(page).to have_css('.category-title', text: search2.title)
    expect(page).to have_css('.item-count', text: /\d+ items/i)
  end

  it 'allows the curator to omit document counts' do
    uncheck 'Include item counts?'
    fill_in_prefetched_typeahead_field with: 'Title1', wait_for: '[data-type="link_to_search"] [data-browse-fetched]'
    save_page

    expect(page).not_to have_css('.item-count', text: /\d+ items/i)
  end
end
