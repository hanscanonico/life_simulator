# frozen_string_literal: true

class SitemapsController < ApplicationController
  def show
    @show = Sitemaps::ShowPage.build

    render layout: false
  end
end
