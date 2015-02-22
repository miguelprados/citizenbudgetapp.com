# coding: utf-8

namespace :data do
  # @param [Hash] hash a hash
  # @param [Hash] opts optional arguments
  # @option opts [Integer] :offset the number of spaces to indent
  # @option opts [Boolean] :quiet quiet output
  # @return [String]
  def puts_recursive_hash(hash, options = {})
    options[:offset] ||= 0

    out = ''
    hash.each do |k,v|
      case v
      when Hash
        append = puts_recursive_hash(v, options.merge(offset: options[:offset] + 2))
        if append.present?
          out << "#{' ' * options[:offset]}#{k}\n#{append}"
        elsif !options[:quiet] || options[:offset].zero?
          out << "#{' ' * options[:offset]}#{k}\n"
        end
      when Array
        append = puts_recursive_array(v, options.merge(offset: options[:offset] + 2))
        if append.present?
          out << "#{' ' * options[:offset]}#{k}\n#{append}"
        elsif !options[:quiet] || options[:offset].zero?
          out << "#{' ' * options[:offset]}#{k}\n"
        end
      else
        out << puts_recursive_string(v, options.merge(prefix: k.to_s.ljust(24)))
      end
    end
    out
  end

  # @param [Array] array an array
  # @param [Hash] opts optional arguments
  # @option opts [Integer] :offset the number of spaces to indent
  # @option opts [Boolean] :quiet quiet output
  # @return [String]
  def puts_recursive_array(array, options = {})
    options[:offset] ||= 0

    out = ''
    array.each do |v|
      case v
      when Hash
        append = puts_recursive_hash(v, options.merge(offset: options[:offset] + 2))
        if append.present?
          out << "#{' ' * options[:offset]}-\n#{append}"
        end
      when Array
        append = puts_recursive_array(v, options.merge(offset: options[:offset] + 2))
        if append.present?
          out << "#{' ' * options[:offset]}-\n#{append}"
        end
      else
        out << puts_recursive_string(v, options)
      end
    end
    out
  end

  # @param [String] string a string
  # @param [Hash] opts arguments
  # @option opts [Integer] :offset the number of spaces to indent
  # @option opts [Boolean] :quiet quiet output
  # @option opts [String] :prefix text to print before the value
  # @return [String]
  def puts_recursive_string(string, options = {})
    out = ''
    unless options[:quiet] && options[:offset] > 2 && string.to_s[/\A-?(0|[1-9]\d*)(\.\d+)?\z/]
      out << ' ' * options[:offset]
      out << "#{options[:prefix]} " if options[:prefix]
      out << "#{string.inspect}\n"
    end
    out
  end

  desc 'Deletes invalid responses'
  task validate: :environment do
    if ENV['ID'].blank?
      abort 'Usage: bundle exec rake data:validate ID=47cc67093475061e3d95369d # Questionnaire ID'
    end

    responses = Questionnaire.find(ENV['ID']).responses.to_a

    (responses.size - 1).downto(0).each do |i|
      response = responses[i]
      errors = response.validates?

      unless errors.empty?
        puts "#{response.id} is invalid:"

        base = errors.delete :base
        if base
          base.each do |error|
            puts "- #{error}"
          end
        end

        errors.each do |id,error|
          puts "- #{id} #{error}: #{response.answers[id].inspect}"
        end

        puts "Delete? (y/n)"
        if STDIN.gets == "y\n"
          response.destroy
          puts "Deleted #{response.id}\n\n"
        end
      end
    end
  end

  # @note If we need to be more sophisticated, we can run non-numeric values through a spam filter.
  desc 'Displays potential spam answers for the end-user to decide whether to keep or reject'
  task ham: :environment do
    class Hash
      # @return [Hash] spam key-value pairs
      def spam
        spam = {}
        each do |k,v|
          if Hash === v || Array === v
            output = v.spam
            spam[k] = output unless output.empty?
          elsif v.to_s[/http|href|src/]
            spam[k] = v
          end
        end
        spam
      end
    end

    # @return [Array] spam values
    class Array
      def spam
        spam = []
        each do |v|
          if Hash === v || Array === v
            output = v.spam
            spam << output unless output.empty?
          elsif v.to_s[/http|href|src/]
            spam << v
          end
        end
        spam
      end
    end

    if ENV['ID'].blank?
      abort 'Usage: bundle exec rake data:ham [MODE=noninteractive] ID=47cc67093475061e3d95369d # Questionnaire ID'
    end

    responses = Questionnaire.find(ENV['ID']).responses.to_a

    # If we process items in-order with #each_with_index, #delete_at will cause
    # items to be skipped. If we process items in reverse order, deleted items
    # will have already been processed.
    (responses.size - 1).downto(0).each do |i|
      response = responses[i]
      spam = response.attributes.spam

      unless spam.empty?
        puts puts_recursive_hash(spam)
        unless ENV['MODE'] == 'noninteractive'
          puts "Is this spam? (y/n)"
        end
        if ENV['MODE'] == 'noninteractive' || STDIN.gets == "y\n"
          response.destroy
          puts "Deleted #{response.id}\n\n"
        end
      end
    end
  end

  desc 'Deletes duplicate responses. If close matches are found, displays the differences for the end-user to decide.'
  task deduplicate: :environment do
    class Response
      DIFF_EXCLUDE_KEYS = %w(_id questionnaire_id initialized_at created_at updated_at)

      # @return [Hash] the attributes with which to calculate the difference
      #   between responses
      def comparable
        attributes.except(*DIFF_EXCLUDE_KEYS)
      end

      # @param [Response] other another response
      # @return [Hash] a hash of differences between this and another response
      def diff(other)
        comparable.diff(other.comparable)
      end

      # @param [Response] other another response
      # @param [Hash] difference a hash of differences between this and the
      #   other response
      # @return [Array] a list of attributes that are non-empty and shared by
      #   both responses
      def intersection(other, difference)
        ((comparable.keys + other.comparable.keys).uniq - difference.keys).select{|key| self[key].present?}
      end
    end

    class Hash
      # @param [Hash] other another hash
      # @return [Hash] a hash of differences between this and another hash
      # @see http://stackoverflow.com/a/7178108
      def diff(other)
        set = keys + other.keys
        set.uniq.each_with_object({}) do |key,memo|
          old_value = self[key]
          new_value = other[key]

          # The fingerprint effectively pairs tokens with alternative spacing,
          # punctuation and capitalization, e.g. postal codes.
          old_test = String === old_value ? old_value.fingerprint : old_value
          new_test = String === new_value ? new_value.fingerprint : new_value

          unless old_test == new_test
            memo[key] = if Hash === old_value && Hash === new_value
              old_value.diff(new_value)
            else
              [old_value, new_value]
            end
          end
        end
      end
    end

    class Fixnum
      # @return [Integer] the factorial of the number
      # @note This implementation only works for numbers greater than zero.
      def factorial
        (1..self).reduce(:*)
      end

      # @param [Integer] k the size of a combination
      # @return [Integer] the number of k-combinations of a set of n elements
      def combinations(k)
        self.factorial / (k.factorial * (self - k).factorial)
      end
    end

    class String
      # Downcases and removes whitespace, punctuation and control characters.
      #
      # @return [String] the fingerprint of the string
      def fingerprint
        UnicodeUtils.downcase(gsub(/[[:space:]]|\p{Punct}|\p{Cntrl}/, ''))
      end
    end

    if ENV['ID'].blank?
      abort 'Usage: bundle exec rake data:deduplicate [MODE=interactive] ID=47cc67093475061e3d95369d # Questionnaire ID'
    end

    responses = Questionnaire.find(ENV['ID']).responses.to_a
    progressbar = ProgressBar.create(format: '%a |%B| %p%% %e', length: 80, smoothing: 0.5, total: responses.size.combinations(2))
    total = responses.last.answers.size
    threshold = ENV['THRESHOLD'] ? ENV['THRESHOLD'].to_i : total / 4
    maybes = 0

    (responses.size - 2).downto(0).each do |i|
      a = responses[i]

      responses.drop(i + 1).each_with_index do |b,j|
        progressbar.increment
        difference = a.diff(b)
        intersection = a.intersection(b, difference)
        count = difference.key?('answers') ? difference['answers'].size : 0

        # If all values are shared:
        if difference.size.zero?
          b.destroy
          responses.delete_at(i + j + 1)
          puts "Deleted #{b.id} (duplicates #{a.id})\n"
        elsif intersection.size.nonzero? && count < threshold # && difference.size <= 3 intersection != ['ip'] && intersection.include?('email')
          if ENV['MODE'] == 'interactive'
            puts
            puts puts_recursive_hash(difference, skip_numeric_children: true)
            puts "Are #{a.id} and #{b.id} duplicates (difference on #{difference.keys.to_sentence})? (y/n)"
            puts "- Same and non-empty on #{intersection.to_sentence} (#{intersection.map{|key| a[key]}.to_sentence})"
            if STDIN.gets == "y\n"
              b.destroy
              responses.delete_at(i + j + 1)
              puts "Deleted #{b.id}\n\n"
            end
          else
            maybes += 1
          end
        end
      end
    end

    puts "#{maybes} comparisons require manual checking (less than #{threshold} of #{total} answers differ)"
  end
end
