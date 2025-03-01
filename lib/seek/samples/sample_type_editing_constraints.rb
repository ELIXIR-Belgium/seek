module Seek
  module Samples
    # collects details from the associated sample attributes to indicate what can be edited
    # e.g if samples have a particular attribute that is blank, then it cannot be set to required or title
    class SampleTypeEditingConstraints
      attr_reader :sample_type
      delegate :samples, to: :sample_type
      delegate :is_isa_json_compliant?, to: :sample_type

      def initialize(sample_type)
        fail Exception.new('Sample type cannot be nil') unless sample_type
        @sample_type = sample_type
      end

      def samples?
        samples.any?
      end

      # an attribute can be changed to required, if no samples have that field blank
      # attr can be the attribute accessor name, or the attribute itself
      # if attr is nil, indicates a new attribute. required is not allowed if there are already samples
      def allow_required?(attr)
        if attr.is_a?(SampleAttribute)
          return true if attr.new_record? && @sample_type.new_record?
          return false if inherited?(attr)

          attr = attr.accessor_name
        end

        return !samples? unless attr
        return !blanks?(attr) if samples?

        true
      end

      # an attribute could be removed if all are currently blank
      # attr can be the attribute accessor name, or the attribute itself
      def allow_attribute_removal?(attr)
        if attr.is_a?(SampleAttribute)
          return true if attr.new_record? && !inherited?(attr)
          return false if inherited?(attr) && attr.required?

          attr = attr.accessor_name
        end
        if attr
          all_blank?(attr)
        else
          true
        end
      end

      # This method was left in so it can be changed in the future
      # Currently, it always returns true
      # see https://github.com/seek4science/seek/pull/2032#discussion_r1813137258
      def allow_new_attribute?
        true
      end
      # whether the type for the attribute can be changed
      def allow_type_change?(attr)
        if attr.is_a?(SampleAttribute)
          return true if attr.new_record?
          return false if inherited?(attr)

          attr = attr.accessor_name
        end
        if attr
          all_blank?(attr)
        else
          true
        end
      end

      def allow_isa_tag_change?(attr)
        if attr.is_a?(SampleAttribute)
          return false if inherited?(attr)

          attr = attr.accessor_name
        end

        if attr
          all_blank?(attr)
        else
          true
        end
      end

      def refresh_cache
        do_analysis
      end

      private

      def inherited?(attr)
        attr&.inherited_from_template_attribute? && is_isa_json_compliant?
      end

      def blanks?(attr)
        !analysis_hash.key?(attr.to_sym) || analysis_hash[attr.to_sym][:has_blanks]
      end

      def all_blank?(attr)
        !analysis_hash.key?(attr.to_sym) || analysis_hash[attr.to_sym][:all_blank]
      end

      def analysis_hash
        @analysis_hash ||= do_analysis
        @analysis_hash
      end

      def do_analysis
        analysis = {}
        sample_type.sample_attributes.each do |attr|
          analysis[attr.accessor_name.to_sym] = analyse_for_attribute(attr)
        end
        analysis
      end

      def analyse_for_attribute(attr)
        has_blanks = false
        all_blank = true
        samples.each do |sample|
          value = sample.get_attribute_value(attr)
          has_blanks = attr.test_blank?(value) unless has_blanks
          all_blank &&= attr.test_blank?(value)
          break if has_blanks && !all_blank # no need to continue
        end
        { has_blanks: has_blanks, all_blank: all_blank }
      end

    end
  end
end
