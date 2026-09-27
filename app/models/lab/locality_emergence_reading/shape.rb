# frozen_string_literal: true

module Lab
  module LocalityEmergenceReading
    # H-shape over the finite radii: `fit` is Stats::QuadraticLogistic's over their finished
    # runs, nil where the arms are not testable or the fit did not settle. Shown where the
    # radius² coefficient is negative, its two-sided Wald p below SHAPE_LEVEL and the fitted
    # peak strictly inside SHAPE_RADII's range; not shown otherwise. Well-mixed is not a
    # distance: it is left out of the fit and reported beside it.
    Shape = Data.define(:arms, :fit) do
      def self.read(arms)
        probe = new(arms: arms, fit: nil)
        probe.testable? ? probe.with(fit: Stats::QuadraticLogistic.fit(probe.groups)) : probe
      end

      def fitted_arms = arms.select { |arm| SHAPE_RADII.include?(arm.radius) && arm.finished? }

      def well_mixed_arm = arms.find { |arm| arm.radius == WELL_MIXED }

      def groups = fitted_arms.map { |arm| [arm.radius, arm.emerged, arm.finished] }

      def testable?
        emerged = fitted_arms.sum(&:emerged)
        fitted_arms.size >= MIN_SHAPE_RADII && emerged.positive? && emerged < fitted_arms.sum(&:finished)
      end

      def peak = fit&.peak

      def shown?
        !fit.nil? && fit.quadratic.negative? && fit.wald_p < SHAPE_LEVEL && peak > SHAPE_RADII.min &&
          peak < SHAPE_RADII.max
      end

      def outcome
        return :untested unless testable?
        return :no_fit if fit.nil?

        shown? ? :shown : :not_shown
      end

      def outcome_label = OUTCOME_LABELS.fetch(outcome)

      def badge_class = OUTCOME_BADGES.fetch(outcome)

      def line = ["H-shape #{outcome_label}", fit_line, well_mixed_line].compact.join("; ")

      private

      def fit_line
        return "fewer than #{MIN_SHAPE_RADII} finite radii with a finished run, or no contrast" unless testable?
        return "the fit did not settle" if fit.nil?

        "radius² coefficient #{format('%.5f', fit.quadratic)}, Wald p = #{format('%.5f', fit.wald_p)}, " \
          "fitted peak #{peak.nil? ? 'none' : format('%.2f', peak)}"
      end

      def well_mixed_line
        return nil unless well_mixed_arm&.finished?

        "well-mixed, not fitted: #{well_mixed_arm.emerged}/#{well_mixed_arm.finished}"
      end
    end
  end
end
