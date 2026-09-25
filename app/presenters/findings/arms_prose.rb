# frozen_string_literal: true

module Findings
  # The agreement and joining a sentence composed from counted arms needs, shared by the
  # presenters that write a finding's claim from its arms.
  module ArmsProse
    private

    def verb_for(count, forms) = count == 1 ? forms.first : forms.last

    def counted(count, noun) = "#{count} #{count == 1 ? noun : noun.pluralize}"

    def sentence_of(parts) = parts.to_sentence(last_word_connector: " and ", two_words_connector: " and ")
  end
end
