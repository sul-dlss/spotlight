# frozen_string_literal: true

namespace :spotlight do
  desc 'Create an initial admin user'
  task initialize: :environment do
    puts 'Creating an initial admin user.'
    u = prompt_to_create_user

    Spotlight::Role.create(user: u, resource: Spotlight::Site.instance, role: 'admin')
    puts 'User created.'
  end

  desc 'Add application-wide admin privileges to a user'
  task admin: :environment do
    u = prompt_to_create_user
    Spotlight::Role.create(user: u, resource: Spotlight::Site.instance, role: 'admin')
  end

  desc 'Create a new exhibit'
  task exhibit: :environment do
    print 'Exhibit title: '
    title = $stdin.gets.chomp

    exhibit = Spotlight::Exhibit.create!(title: title)

    puts 'Who can admin this exhibit?'

    u = prompt_to_create_user

    Spotlight::Role.create(user: u, resource: exhibit, role: 'admin')
    puts 'Exhibit created.'
  end

  desc 'Import an exhibit'
  task :import, [:exhibit_slug] => :environment do |_, args|
    contents = if ENV['FILE']
                 File.read(ENV['FILE'])
               else
                 STDIN.read
               end

    data = JSON.parse(contents)

    slug = args[:exhibit_slug] || data['slug']

    exhibit = Spotlight::Exhibit.find_or_create_by! slug: slug do |e|
      e.title = data['title']
    end

    exhibit.import data

    exhibit.save!

    exhibit.reindex_later
  end

  desc 'Export an exhibit as JSON'
  task :export, [:exhibit_slug] => :environment do |_, args|
    exhibit = Spotlight::Exhibit.find_by(slug: args[:exhibit_slug])

    puts Spotlight::ExhibitExportSerializer.new(exhibit).to_json
  end

  desc 'Migrate to IIIF'
  task :migrate_to_iiif, [:hostname] => :environment do |_, args|
    if args[:hostname]
      require 'migration/iiif'
      Migration::IIIF.run args[:hostname]
    else
      warn "\nUsage: rake spotlight:migrate_to_iiif[hostname]\n\n  Example: rake spotlight:migrate_to_iiif[https://exhibits.stanford.edu]\n\n"
    end
  end

  desc 'Migrate page\'s FriendlyId::Slug to a scoped language'
  task migrate_pages_language: :environment do
    require 'migration/page_language'
    Migration::PageLanguage.run
  end

  desc 'Migrate page\'s FriendlyId::Slug to a scoped page type'
  task migrate_pages_slug_type: :environment do
    require 'migration/add_page_type_to_friendly_id_scope'
    Migration::AddPageTypeToFriendlyIdScope.run
  end

  def prompt_to_create_user
    Spotlight::Engine.user_class.find_or_create_by!(email: prompt_for_email) do |u|
      puts 'User not found. Enter a password to create the user.'
      u.password = prompt_for_password
    end
  rescue StandardError => e
    puts e
    retry
  end

  def prompt_for_email
    print 'Email: '
    $stdin.gets.chomp
  end

  def prompt_for_password
    begin
      system 'stty -echo'
      print 'Password (must be 8+ characters): '
      password = $stdin.gets.chomp
      puts "\n"
    ensure
      system 'stty echo'
    end
    password
  end

  namespace :check do
    desc 'Check the Solr connection and controller configuration'
    task :solr, [:model_name] => ['blacklight:check:solr', :environment] do |_, _args|
      errors = 0

      puts "[#{Blacklight.default_index.connection.uri}]"

      print ' - atomic updates:'
      begin
        id = 'test123'
        field = "test_#{Spotlight::Engine.config.solr_fields.string_suffix}"
        sample_doc = { Spotlight::Engine.blacklight_config.document_model.unique_key => id, field => { set: 'a-new-string' } }
        Blacklight.default_index.connection.add Spotlight::Engine.blacklight_config.document_model.unique_key.to_sym => id, field => 'some-string'
        Blacklight.default_index.connection.update data: [sample_doc].to_json, headers: { 'Content-Type' => 'application/json' }
        Blacklight.default_index.connection.delete_by_id id
        print " OK\n"
      rescue StandardError => e
        errors += 1
        puts e.to_s
      end

      exit 1 if errors > 0
    end
  end

  task :reindex, [:exhibit_slug] => :environment do |_, args|
    exhibits = if args[:exhibit_slug]
                 Spotlight::Exhibit.where(slug: args[:exhibit_slug])
               else
                 Spotlight::Exhibit.all
               end

    exhibits.find_each do |e|
      puts " == Reindexing #{e.title} =="
      e.reindex_later
    end
  end
end
