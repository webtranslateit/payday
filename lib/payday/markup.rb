# frozen_string_literal: true

module Payday

  # Converts the Prawn +inline_format+ markup Payday used to accept in notes and line item
  # descriptions into structured runs that the Typst template can style.
  #
  # We deliberately produce data rather than Typst source. The template renders each run's
  # +text+ as a literal string, so a customer-supplied description can never become Typst
  # code. Never change this to emit markup.
  class Markup

    TAG = %r{<(?<name>b|i|u|strikethrough|sub|sup|font|color|link)(?<attrs>[^>]*)>(?<body>.*?)</\k<name>>}m
    LINE_BREAK = %r{<br\s*/?>}

    # Returns an Array of Hashes, each with a :text key and any of :bold, :italic, :underline,
    # :strike, :sub, :sup, :size, :color and :link. Returns nil when there is nothing to render.
    def self.to_runs(text)
      return nil if text.nil?

      runs(text.to_s.gsub(LINE_BREAK, "\n"), {})
    end

    def self.runs(text, style)
      result = []
      position = 0

      while (match = TAG.match(text, position))
        result << style.merge(text: text[position...match.begin(0)]) if match.begin(0) > position
        result.concat(runs(match[:body], style.merge(style_for(match[:name], match[:attrs]))))
        position = match.end(0)
      end

      result << style.merge(text: text[position..]) if position < text.length
      result
    end
    private_class_method :runs

    def self.style_for(name, attrs)
      case name
      when 'b' then {bold: true}
      when 'i' then {italic: true}
      when 'u' then {underline: true}
      when 'strikethrough' then {strike: true}
      when 'sub' then {sub: true}
      when 'sup' then {sup: true}
      when 'font' then {size: attrs[/size=['"](\d+)['"]/, 1].to_i}
      when 'color' then {color: attrs[/rgb=['"]#?(\h{6})['"]/, 1]}
      when 'link' then {link: attrs[/href=['"](.*?)['"]/, 1]}
      end
    end
    private_class_method :style_for

  end

end
