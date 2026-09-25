# frozen_string_literal: true

# Capybara only waits on its own node matchers, so a computed style read through
# evaluate_script can land in the gap between the document being ready and the stylesheet
# being applied and come back with the property's initial value. This retries the read on
# Capybara's own budget until the block accepts what it returns, then hands back the last
# value either way so the expectation around it still reports the real one.
module SettledScript
  def settled_script(script)
    value = nil

    begin
      page.document.synchronize do
        value = page.evaluate_script(script)
        raise Capybara::ElementNotFound, "script has not settled: #{value.inspect}" unless yield(value)
      end
    rescue Capybara::ElementNotFound
      nil
    end

    value
  end
end

RSpec.configure { |config| config.include SettledScript, type: :system }
