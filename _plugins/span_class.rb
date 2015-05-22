module Jekyll
  module SpanWithClass
    def sc(input, second_arg)
      "<span class=\"#{second_arg}\">#{input}</span>"
    end
  end
end

Liquid::Template.register_filter(Jekyll::SpanWithClass)
