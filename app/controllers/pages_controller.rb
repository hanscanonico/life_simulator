# frozen_string_literal: true

class PagesController < ApplicationController
  def how_it_works
    @show = Pages::HowItWorksPage.build
  end
end
