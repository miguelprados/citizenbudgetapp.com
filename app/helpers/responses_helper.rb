module ResponsesHelper
  def logo
    options = {alt: ''}
    if @questionnaire.logo_height?
      options[:height] = [@questionnaire.logo_height, 100].min
    end
    link_to_unless_current image_tag(@questionnaire.logo.large.url, options), root_path
  end

  # @param [String] custom a custom string
  # @param [String] default a default string
  # @return [String] the custom string if present, the default string otherwise
  def custom_or_default(custom, default)
    if custom.present?
      custom
    else
      default
    end
  end

  # @param [String] string a string
  # # @return [String] the string surrounded by locale-appropriate curly quotes
  def curly_quote(string)
    "#{t(:left_quote)}#{string}#{t(:right_quote)}"
  end

  # @param [String] string a string
  # @return [String] the string with escaped double-quotes for use in HTML attributes
  def escape_attribute(string)
    string.gsub '"', '&quot;'
  end

  # @return [Boolean] whether there is a single section
  def simple_navigation?
    @simulator.one?
  end

  # @param [Section] section a questionnaire section
  # @return [String] the value of the HTML `id` attribute for the section
  def table_id(section)
    parts = []
    parts << 'section'
    parts << section.position + 1
    parts << section.title.parameterize if section.title.present?
    parts.map(&:to_s) * '-'
  end

  # @param [Question] question a questionnaire question
  # @return [Hash] the HTML attributes for the question's `input` tag
  def html_attributes(question)
    attributes = {}
    classes = []

    value = question.default_value
    attributes[:value] = value if value.present?

    [:size, :maxlength, :placeholder, :rows, :cols].each do |attribute|
      value = question[attribute]
      attributes[attribute] = value if value.present?
    end

    if question.size.present? || question.cols.present?
      span = case question.size || question.cols # 210px is the default
      when 0..5
        'span1' # 50px
      when 6..18
        'span2' # 130px
      when 33..45
        'span4' # 290px
      when 46..58
        'span5' # 370px
      when 59..72
        'span6' # 450px
      when 73..85
        'span7' # 530px
      when 86..98
        'span8' # 610px
      when 99..112
        'span9' # 690px
      when 113..125
        'span10' # 770px
      end
      classes << span if span
    end

    if question.required?
      attributes[:required] = Formtastic::FormBuilder.use_required_attribute
      classes << 'validate[required]'
    end

    attributes[:class] = classes.join(' ') unless classes.empty?
    attributes
  end

  def twitter_button(options = {})
    html_options = {
      'class'      => 'twitter-share-button',
      'data-count' => 'horizontal',
      'data-lang'  => iso639_locale,
    }
    if @questionnaire
      html_options['data-text'] = @questionnaire.twitter_text if @questionnaire.twitter_text?
      html_options['data-url']  = @questionnaire.domain_url
      html_options['data-via']  = @questionnaire.twitter_screen_name if @questionnaire.twitter_screen_name?
    end
    link_to nil, 'http://twitter.com/share', html_options.merge(options)
  end

  def facebook_button(options = {})
    html_options = {
      'class'           => 'fb-like',
      'data-send'       => 'true',
      'data-layout'     => 'button_count',
      'data-show-faces' => 'false',
      'data-width'      => t(:facebook_width),
    }
    if @questionnaire
      html_options['data-href'] = @questionnaire.domain_url
    end
    content_tag(:div, nil, html_options.merge(options))
  end

  # Only strip zeroes if all are insignificant.
  def currency(number, options = {})
    escaped_separator = Regexp.escape t(:'number.currency.format.separator', default: [:'number.format.separator', '.'])
    # Inexplicably, -0.0 renders as "-0" instead of 0 without this line.
    number = 0 if number.zero?
    # This logic should be in number_with_precision, but as long as the
    # separator occurs only once, this is safe.
    number_to_currency(number, options).sub /#{escaped_separator}0+\b/, ''
  end
end
