# frozen_string_literal: true

module Payday

  # Extra pages compiled onto the end of an invoice.
  #
  #   appendix = Payday::Appendix.new(
  #     source: File.read('appendix.typ'),
  #     inputs: {'shipments' => shipments.to_json},
  #     dependencies: {'chart.svg' => File.binread('chart.svg')}
  #   )
  #   invoice.render_pdf(appendix: appendix)
  #
  # +source+ is Typst markup appended to Payday's own template, so it is compiled as part of
  # the invoice rather than as a second document that would then have to be merged in. Two
  # things follow from that. The template's +#set page+ rules stay in force, so the appended
  # pages keep the invoice's margins; and the page counter runs across the whole document, so
  # the numbering footer counts the appended pages. A one-page invoice with one appended page
  # numbers "1 / 2", and a three-page invoice continues into "4 / 4".
  #
  # That is also why the source is concatenated rather than +#include+d: an included file is
  # its own module, and the page rules set inside the template would stop at its edge.
  #
  # **Pass your data through +inputs+, never through +source+.** Inputs reach the template as
  # sys_inputs JSON, where Typst treats every string as literal text, which is what stops a
  # customer-supplied field from affecting the layout. Source is code. Interpolating invoice
  # data into it gives that data back the run of the document, and hands anyone who can set a
  # field on an invoice a way to write Typst.
  #
  # +dependencies+ are files the source can reach by name -- +image("chart.svg")+ and the
  # like. Keys are file names, values are the bytes.
  Appendix = Data.define(:source, :inputs, :dependencies) do

    # Accepts an Appendix, a Hash of the same attributes, or nil.
    def self.wrap(value)
      return value if value.nil? || value.is_a?(Appendix)

      new(**value)
    end

    def initialize(source:, inputs: {}, dependencies: {})
      super(source: source, inputs: inputs.transform_keys(&:to_s), dependencies: dependencies.transform_keys(&:to_s))
    end

  end

end
