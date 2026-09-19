# frozen_string_literal: true

require "rails_helper"

# config/application.rb requires railties one at a time rather than `rails/all`, so a
# generator or a `rails app:update` can quietly put Action Text back — and Action Text
# hard-requires Active Storage, which then wants a storage.yml and a variant processor.
# Nothing else in the suite notices an engine the app never calls into.
RSpec.describe "The railties the app boots" do
  subject(:railties) { Rails.application.railties.map { |railtie| railtie.class.name } }

  it "loads no Active Storage" do
    expect(railties).not_to include("ActiveStorage::Engine")
  end

  it "loads no Action Text" do
    expect(railties).not_to include("ActionText::Engine")
  end

  it "loads no Action Mailbox" do
    expect(railties).not_to include("ActionMailbox::Engine")
  end

  it "mounts none of their routes" do
    paths = Rails.application.routes.routes.map { |route| route.path.spec.to_s }

    expect(paths.grep(%r{\A/rails/(active_storage|conductor)})).to be_empty
  end
end
