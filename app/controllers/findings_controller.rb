# frozen_string_literal: true

class FindingsController < ApplicationController
  def index
    @index = Findings::IndexPage.build
  end

  def show
    finding = Findings::Registry.find(params.expect(:id))
    raise ActiveRecord::RecordNotFound, "no finding #{params[:id].inspect}" if finding.nil?

    @show = Findings::ShowPage.build(finding: finding, paginate: method(:pagy))
  end
end
