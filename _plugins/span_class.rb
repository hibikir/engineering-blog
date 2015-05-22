module Jessitron
  module SpanWithClass
    def sc(input, second_arg)
      "<span class=\"#{second_arg}\">#{input}</span>"
    end
  end
end

Liquid::Template.register_filter(Jessitron::SpanWithClass)
