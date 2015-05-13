module Jekyll
  module BananaFilter
    def banana(input)
      puts "banana banana #{input}"
      "<span class='banana'>#{input}</span>"
    end
    def classify(input)
      "<span class='#{input}'>#{input}</span>"
    end

    def method_missing(m, *args, &block)
      puts "Sneaky sneaky template time"
      "<span class='#{m}'>#{args[0]}</span"
    end
  end

  puts "I AM THE QALRUD"
end

Liquid::Template.register_filter(Jekyll::BananaFilter)