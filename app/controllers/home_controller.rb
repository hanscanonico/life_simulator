# frozen_string_literal: true

class HomeController < ApplicationController
  def show
    @show = Home::ShowPage.build
  end
end
